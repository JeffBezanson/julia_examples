macs = split(readall("instances.txt"))

nworkers_per_node = 0

for idx in 1:length(macs)
    macs[idx] = string("ubuntu@", macs[idx])
end

for idx in 1:nworkers_per_node
    addprocs(macs, sshflags=`-i /home/ubuntu/jublr.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no`)
    println("num workers: $(nworkers())")
end

require("ccconsts.jl")
require("ccutils.jl")
require("ccindexer.jl")
require("ccsearcher.jl")

# create_index(2)
# search_index("word")
