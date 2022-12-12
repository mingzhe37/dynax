# Define the problem to solve
using Optimization, ForwardDiff, Zygote

rosenbrock(x, p) =  (p[1] - x[1])^2 + p[2] * (x[2] - x[1]^2)^2
x0 = zeros(2)
_p  = [1.0, 100.0]

f = OptimizationFunction(rosenbrock, Optimization.AutoForwardDiff())
l1 = rosenbrock(x0, _p)
prob = OptimizationProblem(f, x0, _p)

## Optim.jl Solvers

using OptimizationOptimJL

# Start with some derivative-free optimizers

sol = solve(prob, SimulatedAnnealing())
prob = OptimizationProblem(f, x0, _p, lb=[-1.0, -1.0], ub=[0.8, 0.8])
sol = solve(prob, SAMIN())

l1 = rosenbrock(x0, _p)
prob = OptimizationProblem(rosenbrock, x0, _p)
sol = solve(prob, NelderMead())

# Now a gradient-based optimizer with forward-mode automatic differentiation

optf = OptimizationFunction(rosenbrock, Optimization.AutoForwardDiff())
prob = OptimizationProblem(optf, x0, _p)
sol = solve(prob, BFGS())

# Now a second order optimizer using Hessians generated by forward-mode automatic differentiation

sol = solve(prob, Newton())

# Now a second order Hessian-free optimizer

sol = solve(prob, Optim.KrylovTrustRegion())

# Now derivative-based optimizers with various constraints

cons = (res,x,p) -> res .= [x[1]^2 + x[2]^2]
optf = OptimizationFunction(rosenbrock, Optimization.AutoForwardDiff();cons= cons)

prob = OptimizationProblem(optf, x0, _p, lcons = [-Inf], ucons = [Inf])
sol = solve(prob, IPNewton()) # Note that -Inf < x[1]^2 + x[2]^2 < Inf is always true

prob = OptimizationProblem(optf, x0, _p, lcons = [-5.0], ucons = [10.0])
sol = solve(prob, IPNewton()) # Again, -5.0 < x[1]^2 + x[2]^2 < 10.0

prob = OptimizationProblem(optf, x0, _p, lcons = [-Inf], ucons = [Inf],
                           lb = [-500.0,-500.0], ub=[50.0,50.0])
sol = solve(prob, IPNewton())

prob = OptimizationProblem(optf, x0, _p, lcons = [0.5], ucons = [0.5],
                           lb = [-500.0,-500.0], ub=[50.0,50.0])
sol = solve(prob, IPNewton()) # Notice now that x[1]^2 + x[2]^2 ≈ 0.5:
                              # cons(sol.minimizer, _p) = 0.49999999999999994

function con_c(res,x,p)
    res .= [x[1]^2 + x[2]^2]
end

optf = OptimizationFunction(rosenbrock, Optimization.AutoForwardDiff();cons= con_c)
prob = OptimizationProblem(optf, x0, _p, lcons = [-Inf], ucons = [0.25^2])
sol = solve(prob, IPNewton()) # -Inf < cons_circ(sol.minimizer, _p) = 0.25^2

function con2_c(res,x,p)
    res .= [x[1]^2 + x[2]^2, x[2]*sin(x[1])-x[1]]
end

optf = OptimizationFunction(rosenbrock, Optimization.AutoForwardDiff();cons= con2_c)
prob = OptimizationProblem(optf, x0, _p, lcons = [-Inf,-Inf], ucons = [Inf,Inf])
sol = solve(prob, IPNewton())



# Now let's switch over to OptimizationOptimisers with reverse-mode AD

using OptimizationOptimisers
optf = OptimizationFunction(rosenbrock, Optimization.AutoZygote())
prob = OptimizationProblem(optf, x0, _p)
sol = solve(prob, Adam(0.05), maxiters = 1000, progress = false)

## Try out CMAEvolutionStrategy.jl's evolutionary methods

#using OptimizationCMAEvolutionStrategy
#sol = solve(prob, CMAEvolutionStrategyOpt())

## Now try a few NLopt.jl solvers with symbolic differentiation via ModelingToolkit.jl

using OptimizationNLopt, ModelingToolkit
optf = OptimizationFunction(rosenbrock, Optimization.AutoModelingToolkit())
prob = OptimizationProblem(optf, x0, _p)

sol = solve(prob, Opt(:LN_BOBYQA, 2))
sol = solve(prob, Opt(:LD_LBFGS, 2))

## Add some box constraints and solve with a few NLopt.jl methods

prob = OptimizationProblem(optf, x0, _p, lb=[-1.0, -1.0], ub=[0.8, 0.8])
sol = solve(prob, Opt(:LD_LBFGS, 2))
# sol = solve(prob, Opt(:G_MLSL_LDS, 2), nstart=2, local_method = Opt(:LD_LBFGS, 2), maxiters=10000)

## Evolutionary.jl Solvers

using OptimizationEvolutionary
sol = solve(prob, CMAES(μ =40 , λ = 100),abstol=1e-15) # -1.0 ≤ x[1], x[2] ≤ 0.8

## BlackBoxOptim.jl Solvers

#using OptimizationBBO
#prob = Optimization.OptimizationProblem(rosenbrock, x0, _p, lb=[-1.0, 0.2], ub=[0.8, 0.43])
#sol = solve(prob, BBO_adaptive_de_rand_1_bin()) # -1.0 ≤ x[1] ≤ 0.8, 0.2 ≤ x[2] ≤ 0.43