## determine a filename to use for the index of a given archive
function archive_to_index_filename(archive::URI)
    # since we may end up encountering archive files files from different segments
    # in the crawl corpus with the same name, create a unique id as hash of the full URL.
    uniqid = bytes2hex(AWS.Crypto.md5(archive.path))
    joinpath(part_idx_location, "$(uniqid).jser")
end

## create an inverse index object for an archive from the given CrawlCorpus
## this object is a tuple (idx, names) of the inverse index and an array of
## document names (to recover names from document IDs)
function archive_to_index(cc::CrawlCorpus, archive::URI)
    t1 = time()
    # read all entries from the archive
    f = open(cc, archive)
    entries = read_entries(cc, f, "text/")
    close(f)

    # create a corpus of StringDocuments
    docs = {}
    for entry in entries
        # ignoring anything otherthan ascii for this example
        ascstr = convert(ASCIIString, entry.data, "")
        sd = StringDocument(ascstr)
        sd.metadata = TextAnalysis.DocumentMetadata()
        sd.metadata.name = entry.uri
        push!(docs, sd)
    end
    crps = Corpus(docs)

    # process the corpus
    crps = preprocess(crps)
    update_inverse_index!(crps)
    invidx = inverse_index(crps)
    docs = documents(crps)

    println("\tprocessing time $(time()-t1)secs")

    return (invidx, [ docs[i].metadata.name for i = 1:length(docs) ])
end

##
# execute index creation parallely for n_archives archive files
function create_index(n_archives::Int)
    cc = CrawlCorpus(docs_location, true)

    arc_file_uris = archives(cc, n_archives)

    println("about to index $(length(arc_file_uris)) archive files")

    ## YOUR CODE HERE ##
    @parallel for arc in arc_file_uris
        as_serialized(archive_to_index(cc, arc),
                      archive_to_index_filename(arc))
    end
end
