using Kinbiont
using DifferentialEquations
using CSV
using SymbolicRegression
using Plots
using StatsBase
using Distributions

# In this example, we will use Kinbiont to generate data about a single species. We suppose that the growth rate depends on an experimental feature (mu = 1 / (1 + feature)) that the user can tune (make different experiments).
# But we suppose that the user does not know how this experimental condition affects the growth rate. Then, we perform the experiment at different conditions and fit the data with a simple model, where the growth rate is an effective parameter fixed by the experimental condition (i.e., mu(feature) -> mu_eff).
# Finally, applying symbolic regression on the fitted results, we retrieve the relationship between the experimental feature and the effective growth rate.

# We define the function that alters the growth rate
function unknown_response(feature)
    response = 1 / (1 + feature)
    return response
end

# Defining the used ODE model
results_fit = Any

ODE_models = "baranyi_richards"

ub_1 = [0.2, 5.1, 500.0, 5.0]
lb_1 = [0.0001, 0.1, 0.00, 0.2]
p1_guess = lb_1 .+ (ub_1 .- lb_1) ./ 2

# Defining the range of the perturbation on feature
feature_range = 0.0:0.4:4.0

# Defining the parameters values for the simulation
p_sim = [0.1, 1.0, 50.0, 1.0]
psim_1_0 = p_sim[1]

t_min = 0.0
t_max = 800.0
n_start = [0.1]
delta_t = 5.0
noise_value = 0.02

plot(0, 0)
for f in feature_range
    # Changing the parameters with unknown perturbation
    p_sim[1] = psim_1_0 * unknown_response(f)

    # Calling the simulation function
    sim = Kinbiont.ODE_sim("baranyi_richards", n_start, t_min, t_max, delta_t, p_sim)

    # Adding uniform random noise
    noise_uniform = rand(Uniform(-noise_value, noise_value), length(sim.t))

    data_t = reduce(hcat, sim.t)
    data_o = reduce(hcat, sim.u)
    data_OD = vcat(data_t, data_o)
    data_OD[2, :] = data_OD[2, :] .+ noise_uniform

    # Plotting scatterplot of data with noise
    display(Plots.scatter!(data_OD[1, :], data_OD[2, :], xlabel="Time", ylabel="Arb. Units", label=nothing, color=:red, markersize=2, size=(300, 300)))

    results_ODE_fit = fitting_one_well_ODE_constrained(
        data_OD,
        string(f),
        "test_ODE",
        "baranyi_richards",
        p1_guess;
        lb=lb_1,
        ub=ub_1
    )

    display(Plots.plot!(results_ODE_fit[4], results_ODE_fit[3], xlabel="Time", ylabel="Arb. Units", label=nothing, color=:red, markersize=2, size=(300, 300)))

    if f == feature_range[1]
        results_fit = results_ODE_fit[2]
    else
        results_fit = hcat(results_fit, results_ODE_fit[2])
    end
end

scatter(results_fit[2, :], results_fit[4, :], xlabel="Feature value", ylabel="Growth rate")

# Setting options for symbolic regression
options = SymbolicRegression.Options(
    binary_operators=[+, /, *, -],
    unary_operators=[],
    constraints=nothing,
    elementwise_loss=nothing,
    loss_function=nothing,
    tournament_selection_n=12,
    tournament_selection_p=0.86,
    topn=12,
    complexity_of_operators=nothing,
    complexity_of_constants=nothing,
    complexity_of_variables=nothing,
    parsimony=0.05,
    dimensional_constraint_penalty=nothing,
    alpha=0.100000,
    maxsize=10,
    maxdepth=nothing
)

# Generating feature matrix
# The first column is the label as a string of the feature value we used for the fitting labeling
feature_matrix = [[string(f), f] for f in feature_range]
feature_matrix = permutedims(reduce(hcat, feature_matrix))

# Symbolic regression between the feature and the growth rate (4th row of the results_fit)
gr_sy_reg = Kinbiont.downstream_symbolic_regression(results_fit, feature_matrix, 4; options=options)

scatter(results_fit[2, :], results_fit[4, :], xlabel="Feature value", ylabel="Growth rate")
hline!(unique(gr_sy_reg[3][:, 1]), label=["Eq. 1" nothing], line=(3, :green, :dash))
plot!(unique(results_fit[2, :]), unique(gr_sy_reg[3][:, 2]), label=["Eq. 2" nothing], line=(3, :red))
plot!(unique(results_fit[2, :]), unique(gr_sy_reg[3][:, 3]), label=["Eq. 3" nothing], line=(3, :blue, :dashdot))
