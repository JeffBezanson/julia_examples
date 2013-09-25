##
# Configurable constants
######################################################

using TextAnalysis
using URIParser
using Stemmers
using Blocks
using Base.FS
using CommonCrawl

const fs_pfx             = "/mnt/cc"
const part_idx_location  = joinpath(fs_pfx, "part_idx")
const docs_location      = joinpath(fs_pfx, "docs")
