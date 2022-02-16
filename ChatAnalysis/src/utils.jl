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

# To write a test file.
function writeTestFile(fileName::String)
    open("data/" * "trash_file.txt", "w") do f
        for term in keys(ll)
            write(f, term * " " * "\n")
        end
    end
end

function waitForDb(seconds::Integer)
    t2 = @async begin
        sleep(seconds)
    end
    wait(t2)
end