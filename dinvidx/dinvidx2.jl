using TextAnalysis
using Stemmers
using Blocks
using HDFS
using Base.FS


##
# Configurable constants
######################################################
## constants while working in local file system mode
const fs_pfx = ""
## constants while working in HDFS mode
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = joinpath(fs_pfx, "part_idx")
const doc_to_id_location    = joinpath(fs_pfx, "doc_to_id.jser")
const id_to_doc_location    = joinpath(fs_pfx, "id_to_doc.jser")
const docs_location         = joinpath(fs_pfx, "docs")

const ndocs_per_idx_part    = 10

##
# Utility methods
#########################################################
const _cache = Dict()
cache(k, v) = _cache[k] = v
cache_clear(k) = delete!(_cacle, k)
cache_clear() = empty!(_cache)
function cached_get(k, fn)
    v = get(_cache, k, nothing)
    (nothing != v) && return v
    cache(k, fn())
end

function corpus(pathlist::Array)
    sdlist = {}
    for path in pathlist
        io = open(path)
        text = readall(io)
        text = convert(ASCIIString, text.data, "")
        close(io)
        sd = StringDocument(text)
        sd.metadata = TextAnalysis.DocumentMetadata()
        sd.metadata.name = isa(path, HdfsURL) ? path.url : path
        push!(sdlist, sd)
    end
    Corpus(sdlist)
end

function preprocess(entity::Union(StringDocument,Corpus))
    prepare!(entity, strip_corrupt_utf8 | strip_case | strip_whitespace | strip_non_letters | strip_articles | strip_prepositions | strip_pronouns | strip_stopwords)

    #remove_corrupt_utf8!(entity)
    #remove_case!(entity)
    #remove_whitespace!(entity)
    #remove_nonletters!(entity)
    ##remove_multi!(entity, :punctuation, :numbers, :articles, :indefinite_articles, :definite_articles, :prepositions, :pronouns, :stop_words)
    ##remove_punctuation!(entity)
    ##remove_numbers!(entity)
    #remove_articles!(entity)
    ##remove_indefinite_articles!(entity)
    ##remove_definite_articles!(entity)
    #remove_prepositions!(entity)
    #remove_pronouns!(entity)
    #remove_stop_words!(entity)
    if isa(entity, Corpus) 
        standardize!(entity, TokenDocument) 
    else
        entity = convert(TokenDocument, entity)
    end
    stem!(entity)
    entity
end

function as_inverted_index(crps::Corpus)
    doc_to_id = cached_get(doc_to_id_location, ()->as_deserialized(openable(doc_to_id_location)))

    cdocs = documents(crps)

    update_inverse_index!(crps)
    invidx = inverse_index(crps)

    # update the doc ids in inverted index to global doc ids
    for (n,v) in invidx
        for docidx in 1:length(v)
            docid = v[docidx]
            doc = cdocs[docid]
            path = doc.metadata.name
            newdocid = doc_to_id[path]
            v[docidx] = newdocid
        end
    end

    invidx
end

openable(path::HdfsURL) = path
openable(path::File) = path
openable(path::String) = beginswith(path, "hdfs") ? HdfsURL(path) : File(path)

as_serialized(obj, f::File) = as_serialized(obj, f.path)
function as_serialized(obj, path::Union(String,HdfsURL))
    iob = IOBuffer()
    serialize(iob, obj)

    io = open(path, "w")
    write(io, takebuf_array(iob))
    close(io)
    close(iob)
    path
end


# cache deserialized objs to help the simple search implementation speed up by preventing repeated loading of indices
as_deserialized(f::File) = as_deserialized(f.path)
function as_deserialized(path::Union(String,HdfsURL))
    io = as_io(path)
    if isa(path, HdfsURL)
        iob = IOBuffer(read(io, Array(Uint8, nb_available(io)))) # HDFS does not play nicely with byte size reads
        close(io)
        io = iob
    end
    obj = deserialize(io)
    close(io)
    obj
end

##
# Searching
##########################################################

function search_part_idx(file, terms::Array)
    part_idx = cached_get(file, ()->as_deserialized(file))
    results = IntSet()
    for term in terms
        union!(results, get(part_idx, term, []))
    end
    results
end

function search_index(terms::String)
    sd = StringDocument(terms)
    td = preprocess(sd)
    terms = tokens(td)
    terms = filter(tok->!isempty(tok), terms)

    master_idx = cached_get(part_idx_location, ()->Block(openable(part_idx_location), false, 2))

    result_doc_ids = @parallel union for i in 1:nworkers()
        local_files = {}
        for b in localpart(master_idx)
            append!(local_files, b)
        end
        reduce(union, map(file->search_part_idx(file, terms), local_files))
    end
  
    # map the document ids to file names 
    id_to_doc = cached_get(id_to_doc_location, ()->as_deserialized(openable(id_to_doc_location)))
    result_docs = map(id->get(id_to_doc, id, ""), result_doc_ids)
    filter(x->!isempty(x), result_docs)
end

##
# Indexing
#####################################################
function create_part_index(files)
    crps = corpus(files)
    crps = preprocess(crps)
    as_inverted_index(crps)
end

function create_index()
    blks = Block(openable(docs_location), true, ndocs_per_idx_part)
    num_parts = @parallel (+) for i in 1:nworkers()
        file_lists = localpart(blks)
        np = 0
        for (idx, file_list) in enumerate(file_lists)
            part_idx = create_part_index(file_list)
            path = joinpath(part_idx_location, "$(i)_$(idx).jser")
            as_serialized(part_idx, openable(path))
            np += 1
        end
        np
    end
    println("created $num_parts part indices")
end


##
# assign ids to each document
# create two indexes to be able to search from either direction
function create_docids()
    d_i = Dict{String, Int}()
    i_d = Dict{Int, String}()
    nextid = 1
    function adddoc(doc_list)
        for doc in doc_list
            docpath = isa(doc, HdfsURL) ? doc.url : doc
            d_i[docpath] = nextid
            i_d[nextid] = docpath
            nextid += 1
        end
    end

    # create blocks (of around 1000 paths each) nested under docs_location
    blks = Block(openable(docs_location), true, 1000)
    for doc_list in blocks(blks)
        adddoc(doc_list)
    end

    d_i_loc = as_serialized(d_i, openable(doc_to_id_location))
    i_d_loc = as_serialized(i_d, openable(id_to_doc_location))
    (d_i_loc, i_d_loc)
end

