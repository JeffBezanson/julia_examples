##
# Utility methods
#########################################################

## save an object to a file with the given path
function as_serialized(obj, path::String)
    iob = IOBuffer()
    serialize(iob, obj)
    open(path, "w") do io
        write(io, takebuf_array(iob))
    end
    path
end

## load an object back from a file
function as_deserialized(path::String)
    open(path) do io
        deserialize(io)
    end
end

## clean up text for processing
function preprocess(entity::Union(StringDocument,Corpus))
    prepare!(entity, strip_corrupt_utf8 | strip_case)
    prepare!(entity, strip_patterns, skip_patterns=Set{String}("<script\\b[^>]*>([\\s\\S]*?)</script>"))
    prepare!(entity, strip_patterns, skip_patterns=Set{String}("<[^>]*>"))
    prepare!(entity, strip_whitespace | strip_non_letters | strip_articles | strip_prepositions | strip_pronouns | strip_stopwords)

    if isa(entity, Corpus)
        standardize!(entity, TokenDocument)
    else
        entity = convert(TokenDocument, entity)
    end
    stem!(entity)
    entity
end
