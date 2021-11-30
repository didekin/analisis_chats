using Pkg

Pkg.project().path != joinpath(chat_dir, "Project.toml") && Pkg.activate(".")
["Test"] ∉ keys(Pkg.project().dependencies) && Pkg.add(["Test"])

const src_test = joinpath(chat_dir, "test");
const test_data = joinpath(src_test, "data")