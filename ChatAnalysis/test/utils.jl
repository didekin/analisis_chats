# To write a test file.
function writeTestFile(fileName::String)
    open("data/" * "trash_file.txt", "w") do f
        for term in keys(ll)
            write(f, term * " " * "\n")
        end
    end
end