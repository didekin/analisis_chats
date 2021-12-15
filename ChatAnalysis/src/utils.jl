function dictFromArrWords(words::String)::Dict{String,Integer}
    lexico = Dict{String,Integer}()
    for word in split(words, ' ')
        if word ∉ keys(lexico)
            lexico[word] = 1
        else
            lexico[word] += 1
        end
    end
    lexico
end