macs = split(readall("instances.txt"))

for idx in 1:length(macs)
    macs[idx] = string("ubuntu@", macs[idx])
end

println(macs)
addprocs(macs, sshflags=`-i /home/ubuntu/jublr.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no`)

@everywhere begin
    include("ccconsts.jl")
    run(`sudo rm -rf $fs_pfx`)
    run(`sudo mkdir -p $part_idx_location $docs_location`)
    run(`sudo chmod 777 $fs_pfx $part_idx_location $docs_location`)
end
