##
# Searching
##########################################################

function search_part_idx(indexfile, terms::Array, op="and")
    ## YOUR CODE HERE ##

    # useful functions: get, IntSet, union, intersect, union!, add!
end

function search_index(terms::String)
    sd = StringDocument(terms)
    td = preprocess(sd)
    terms = tokens(td)
    terms = filter(tok->!isempty(tok), terms)

    # The Blocks library provides many ways to divide work among processors.
    # Here, we call it on the part_idx_location directory, which tells it to
    # divide up the files in that directory.
    # The call localpart(master_idx) returns a list of files to be handled
    # by the calling processor.
    master_idx = Block(File(part_idx_location), false, 2)

    ## YOUR CODE HERE ##

end
