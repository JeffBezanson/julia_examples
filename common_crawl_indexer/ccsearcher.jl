##
# Searching
##########################################################

function search_part_idx(file, terms::Array)
    ## YOUR CODE HERE ##

    part_idx, docnames = as_deserialized(file)
    results = IntSet()
    first = true
    for term in terms
        ids = get(part_idx, term, [])
        if first
            union!(results, ids)
            first = false
        else
            intersect!(results, IntSet(ids...))
        end
    end
    { docnames[i] for i in results }
end

function search_index(terms::String)
    sd = StringDocument(terms)
    td = preprocess(sd)
    terms = tokens(td)
    terms = filter(tok->!isempty(tok), terms)

    master_idx = Block(File(part_idx_location), false, 2)

    ## YOUR CODE HERE ##
    result_docs = @parallel union for i in 1:nworkers()
        local_files = {}
        for b in localpart(master_idx)
            append!(local_files, b)
        end
        reduce(union, map(file->search_part_idx(file, terms), local_files))
    end

    println("results:\n$result_docs")
end
