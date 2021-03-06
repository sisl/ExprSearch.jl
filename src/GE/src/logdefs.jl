# *****************************************************************************
# Written by Ritchie Lee, ritchie.lee@sv.cmu.edu
# *****************************************************************************
# Copyright ã 2015, United States Government, as represented by the
# Administrator of the National Aeronautics and Space Administration. All
# rights reserved.  The Reinforcement Learning Encounter Simulator (RLES)
# platform is licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You
# may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0. Unless required by applicable
# law or agreed to in writing, software distributed under the License is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
# _____________________________________________________________________________
# Reinforcement Learning Encounter Simulator (RLES) includes the following
# third party software. The SISLES.jl package is licensed under the MIT Expat
# License: Copyright (c) 2014: Youngjun Kim.
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED
# "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# *****************************************************************************

function logsystem()
    logsys = LogSystem()

    register_log!(logsys, "fitness", ["iter", "fitness"], [Int64, Float64])
    register_log!(logsys, "code", ["iter", "code"], [Int64, String])
    register_log!(logsys, "computeinfo", ["parameter", "value"], [String, Any])
    register_log!(logsys, "parameters", ["parameter", "value"], [String, Any])
    register_log!(logsys, "result", ["fitness", "expr", "best_at_eval", "total_evals"], 
        [Float64, String, Int64, Int64])
    register_log!(logsys, "elapsed_cpu_s", ["nevals", "elapsed_cpu_s"], 
        [Int64, Float64]) 
    register_log!(logsys, "current_best",  ["nevals", "fitness", "expr"], 
        [Int64, Float64, String])
    register_log!(logsys, "fitness5", ["iter", "fitness1", "fitness2", "fitness3",
        "fitness4", "fitness5"], [Int64, Float64, Float64, Float64, Float64, Float64])

    register_log!(logsys, "pop_distr", 
        ["iter", "bin_center", "count", "unique_fitness", "unique_code"], 
        [Int64, Float64, Int64, Int64, Int64], "population",
        x -> begin
            iter, pop = x
            hist_edges = logsys.params["hist_edges"]
            hist_mids = logsys.params["hist_mids"]
            fitness_vec = Float64[pop[i].fitness  for i = 1:length(pop)]
            h = fit(Histogram, fitness_vec, hist_edges)
            edges = h.edges
            counts = h.weights
            uniq_fitness = Int64[]
            uniq_code = Int64[]
            for (e1, e2) in partition(hist_edges, 2, 1)
                subids = filter(i -> e1 <= pop[i].fitness < e2, 1:length(pop))
                subpop = pop[subids]
                n_fit = length(unique(imap(i -> string(subpop[i].fitness), 1:length(subpop))))
                n_code = length(unique(imap(i -> string(subpop[i].code), 1:length(subpop))))
                push!(uniq_fitness, n_fit)
                push!(uniq_code, n_code)
            end
            for (m, c, uf, uc) in zip(hist_mids, counts, uniq_fitness, uniq_code) 
                push!(logs, "pop_distr", [iter, m, c, uf, uc])
            end
        end)
    register_log!(logsys, "pop_diversity", 
        ["iter", "unique_fitness", "unique_code"], [Int64, Int64, Int64], "population", 
        x -> begin
            iter, pop = x
            n_fit = length(unique(imap(i -> string(pop[i].fitness), 1:length(pop))))
            n_code = length(unique(imap(i -> string(pop[i].code), 1:length(pop))))
            push!(logs, "pop_diversity", [iter, n_fit, n_code])
        end)

    register_log!(logsys, "verbose1", ["msg"], [String])
    register_log!(logsys, "current_best_print", ["msg"], [String], "current_best", 
        x->begin
            nevals, fitness, code = x
            code = string(code)
            code_short = take(code, 50) |> join
            return ["nevals: $nevals, max fitness=$(signif(fitness, 4))," *
                         "code=$(code_short)"]
        end)

    logsys
end
