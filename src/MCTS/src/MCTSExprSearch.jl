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

module MCTS  #ExprSearch.MCTS

export MCTSESParams, MCTSESResult, mcts_search, exprsearch, SearchParams, SearchResult 
export get_derivtree

include("DerivTreeMDPs.jl")

using Reexport
using ExprSearch
using RLESUtils, GitUtils, CPUTimeUtils, Observers, LogSystems
import RLESTypes.SymbolTable
@reexport using LinearDerivTrees  #pretty_string
using .DerivTreeMDPs
using GrammaticalEvolution
using GBMCTS

import .DerivTreeMDPs.get_fitness
import ..ExprSearch: SearchParams, SearchResult, exprsearch, ExprProblem, get_grammar, get_fitness,
    get_expr, get_derivtree

include("logdefs.jl")

type MCTSESParams <: SearchParams
  #tree params
  maxsteps::Int64

  #mdp params
  max_neg_reward::Float64
  step_reward::Float64

  #mcts
  n_iters::Int64
  searchdepth::Int64
  exploration_const::Float64
  maxmod::Bool
  q0::Float64
  seed::Int64

  logsys::LogSystem
  userargs::SymbolTable
end
MCTSESParams(maxsteps::Int64, max_neg_reward::Float64, step_reward::Float64, n_iters::Int64,
    searchdepth::Int64, exploration_const::Float64, maxmod::Bool, q0::Float64, seed::Int64,
    logsys::LogSystem=logsystem(); userargs::SymbolTable=SymbolTable()) =
        MCTSESParams(maxsteps, max_neg_reward, step_reward, n_iters, searchdepth, 
        exploration_const, maxmod, q0, seed, logsys, userargs)

type MCTSESResult <: SearchResult
  tree::LinearDerivTree
  actions::Vector{Int64}
  fitness::Float64
  expr::Union{Symbol,Expr}
  best_at_eval::Int64
  totalevals::Int64
end

exprsearch(p::MCTSESParams, problem::ExprProblem) = mcts_search(p, problem::ExprProblem)

get_derivtree(result::MCTSESResult) = get_derivtree(result.tree)
get_expr(result::MCTSESResult) = result.expr
get_fitness(result::MCTSESResult) = result.fitness

function mcts_search(p::MCTSESParams, problem::ExprProblem)
  @notify_observer(p.logsys.observer, "verbose1", ["Starting MCTS search"])
  @notify_observer(p.logsys.observer, "computeinfo", ["starttime", string(now())])

  grammar = get_grammar(problem)
  tree_params = LDTParams(grammar, p.maxsteps)
  mdp_params = DerivTreeMDPParams(grammar, p.max_neg_reward, p.step_reward)

  tree = LinearDerivTree(tree_params)
  mdp = DerivTreeMDP(mdp_params, tree, problem, p.userargs)

  solver = MCTSSolver(n_iterations=p.n_iters, depth=p.searchdepth, 
    exploration_constant=p.exploration_const, maxmod=p.maxmod, rng=MersenneTwister(p.seed))
  policy = MCTSPolicy(solver, mdp, q0=p.q0)

  initialize!(tree)
  s = create_state(mdp)

  tstart = CPUtime_start()
  i = 1
  while !GBMCTS.isexplored(policy.mcts.tree, s) && i <= p.n_iters
    @notify_observer(p.logsys.observer, "iteration", [i])

    simulate(policy, s, p.searchdepth) #FIXME: remove searchdepth??

    @notify_observer(p.logsys.observer, "elapsed_cpu_s", [i, CPUtime_elapsed_s(tstart)])
    best_state = policy.best_state
    @notify_observer(p.logsys.observer, "current_best", [i, -policy.best_reward, 
        string(best_state.past_actions), string(get_expr(best_state))]) #report fitness instead of reward
    @notify_observer(p.logsys.observer, "mcts_tree", [i, policy.mcts.tree, s])

    i += 1
  end
  best_fitness = -policy.best_reward
  expr = get_expr(policy.best_state)
  best_actions = policy.best_state.past_actions
  @notify_observer(p.logsys.observer, "result", [best_fitness, string(expr), policy.best_at_eval, policy.totalevals])

  #meta info
  @notify_observer(p.logsys.observer, "computeinfo", ["endtime",  string(now())])
  @notify_observer(p.logsys.observer, "computeinfo", ["hostname", gethostname()])
  @notify_observer(p.logsys.observer, "computeinfo", ["gitSHA",  get_SHA(dirname(@__FILE__))])
  @notify_observer(p.logsys.observer, "computeinfo", ["cpu_time", CPUtime_elapsed_s(tstart)]) 
  @notify_observer(p.logsys.observer, "parameters", ["maxsteps", p.maxsteps])
  @notify_observer(p.logsys.observer, "parameters", ["max_neg_reward", p.max_neg_reward])
  @notify_observer(p.logsys.observer, "parameters", ["step_reward", p.step_reward])
  @notify_observer(p.logsys.observer, "parameters", ["discount", mdp_params.discount])
  @notify_observer(p.logsys.observer, "parameters", ["n_iters", p.n_iters])
  @notify_observer(p.logsys.observer, "parameters", ["searchdepth", p.searchdepth])
  @notify_observer(p.logsys.observer, "parameters", ["exploration_const", p.exploration_const])
  @notify_observer(p.logsys.observer, "parameters", ["maxmod", p.maxmod])
  @notify_observer(p.logsys.observer, "parameters", ["q0", p.q0])

  return MCTSESResult(tree, best_actions, best_fitness, expr, policy.best_at_eval, policy.totalevals)
end

end #module
