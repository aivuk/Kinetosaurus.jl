
# uploading package this part of the code will be skipped when the github is online 
# you have only to write using JMAKI

using Kimchi
using DifferentialEquations

# loading the functions  (will be skipped when the package is deployed)
#path_to_functions = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/src/";
#include(string(path_to_functions,"/functions.jl"))


# simulating data with a ODE
# string of the model see the github for a partial list
model = "triple_piecewise_adjusted_logistic"
# initial contion of the ODE, note sciML requires vectors
n_start =[0.1]
# starting time of the ODE
tstart =0.0
#ending time of the ODE
tmax = 600.0
# delta t for numerical integration
delta_t = 10.0
# sciML numerical integrator
integrator = KenCarp4()

# parameters of the ODE 
param_of_ode= [0.06, # growth rate
1.0, # carrying capacity
200, # lag time
0.5, # shape factor 
0.001, # linear factor 
450, # stationary start
-0.0002# linear param of stationary phase]
]


# calling the function simulation

sim = ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)


# ploting scatterplot of data
Plots.scatter(sim, xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:blue, size = (300,300))

#adding uniform random noise
noise_unifom = rand(Uniform(-0.05,0.05),length(sim.t))


data_t = reduce(hcat,sim.t)
data_o = reduce(hcat,sim.u)
data_OD = vcat(data_t,data_o)
data_OD[2,:] = data_OD[2,:] .+ noise_unifom
# ploting scatterplot of data with noise

Plots.scatter!(data_OD[1,:],data_OD[2,:], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],color=:blue,markersize =2 ,size = (300,300))

# smooting of the data with rolling average
data_OD_smooth= smoothing_data(data_OD)
# smooting of the data with lowess


data_OD_smooth_3= smoothing_data(data_OD, method = "lowess")

data_OD_smooth=  Matrix(data_OD_smooth)
Plots.scatter(data_OD[1,:],data_OD[2,:], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],color=:black,markersize =2 ,size = (300,300))
Plots.scatter!(data_OD_smooth[1,:],data_OD_smooth[2,:], xlabel="Time", ylabel="Arb. Units", label=["Smoothed data rolling avg" nothing], markersize=2, color=:blue, size = (300,300))
Plots.scatter!(data_OD_smooth_3[1,:],data_OD_smooth_3[2,:], xlabel="Time", ylabel="Arb. Units", label=["Smoothed data lowess " nothing], markersize=2, color=:red, size = (300,300))

# multiple scattering correction, since requires an external file you can comment this part
data_OD_smooth2= correction_OD_multiple_scattering(data_OD_smooth,"/Users/fabrizio.angaroni/Documents/calib_OD600_1ml/ms_cal_v1._ten.csv")
Plots.scatter(data_OD_smooth2[1,:],data_OD_smooth2[2,:], xlabel="Time", ylabel="Arb. Units", label=["Pre-processes data" nothing], markersize=2, color=:blue, size = (300,300))

data_OD_smooth2= correction_OD_multiple_scattering(data_OD_smooth,"/Users/fabrizio.angaroni/Documents/calib_OD600_1ml/ms_cal_v1._ten.csv"; method= "exp_fit")
Plots.scatter!(data_OD_smooth2[1,:],data_OD_smooth2[2,:], xlabel="Time", ylabel="Arb. Units", label=["Pre-processes data" nothing], markersize=2, color=:red, size = (300,300))

# log lin fitting
# first, as example, I evaluate the specific growth rate (i.e. the dynamic of the slope of a log linear fitting of a slinding window)
# size of the win. If 0 the methods involve interpolation between the data point 
pt_smoothing_derivative =7
deriv = specific_gr_evaluation(data_OD, 7)
plot(deriv)
# to be correctet if 0
data_OD_smooth2 =data_OD_smooth
specific_gr_times = [(data_OD_smooth2[1, r] + data_OD_smooth2[1, (r+pt_smoothing_derivative)]) / 2 for r in 1:1:(eachindex(data_OD_smooth2[2, :][end]-pt_smoothing_derivative))]
data_deriv =      Matrix(transpose(hcat(specific_gr_times, deriv)));

# now i fit for real the data with log lin
# path where save the results plots
res_log_lin = fitting_one_well_Log_Lin(data_OD_smooth2, # dataset first row times second row OD
"test", # name of the well
"test"; #label of the experiment
display_plots= true
)

# ODE fitting


# upper bounds of the parameters of the ODE
ub_dhpm =[ 1.2 , 1.1 , 2.0  ,20  ]
# lowert bounds of the parameters of the ODE

lb_dhpm =[ 0.0001 , 0.00000001, 0.00 ,0 ]

# starting guess (i start in the middle. The argument will be changed)

test_param = (ub_dhpm .- lb_dhpm) .+ lb_dhpm ./ 2
path_to_plotting = "/Users/fabrizio.angaroni/Documents/test_jmaki/"

@time results =fitting_one_well_ODE_constrained(data_OD_smooth2, # dataset first row times second row OD
"", # name of the well
"", #label of the experiment
"aHPM", # ode model to `use 
lb_dhpm, # lower bound param
ub_dhpm; # upper bound param
display_plots=true, # do plots or no
path_to_plot=path_to_plotting, # where save plots
PopulationSize = 300,
maxiters = 200,
#integrator = Tsit5(),
integrator = KenCarp4(),
 type_of_loss = "L2")

# testing custom ode

# function of the custom ODE
function ODE_custom(du, u, param, t)

    du[1] =  u[1] * (1 - u[1] )* (param[2])  +  param[1] *  u[1] 

    du[2] = + u[1] * (param[2]) + param[4] * u[2]* ( 1 - (u[1] + u[2])/param[3]) 

    
end

custom_ub = [ 1.2 , 1.1 , 2.0  ,2.0  ]

custom_lb=[ 0.0001 , 0.00000001, 0.00 ,0 ]

function NL_model_exp(p, times)
    model = p[1] .* exp.(times .* p[2])
    return model
end


nl_ub =  [2.0001 , 10.00000001, 500.00]
nl_lb =  [0.0001 , 0.00000001, 0.00 ]
new_param = [0.1, 1.01,0.0]

@time B= fit_NL_model(data_OD_smooth2, # dataset first row times second row OD
"test", # name of the well
"", #label of the experiment
"NL_logistic", # ode model to use
nl_lb, # lower bound param
nl_ub; # upper bound param
u0=new_param,# initial guess param
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=7,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="L2", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=50,
maxiters=9000000,
abstol=0.000000001,
thr_lowess=0.05,
penality_CI = 8
)

nl_ub =  [2.0001 , 10.00000001, 500.00,4]
nl_lb =  [0.0001 , 0.00000001, 0.00,0.1 ]
new_param = [0.1, 1.01,0.0,0.99]


@time M= fit_NL_model_MCMC_intialization(data_OD_smooth2, # dataset first row times second row OD
"test", # name of the well
"", #label of the experiment
"NL_Bertalanffy", # ode model to use
nl_lb, # lower bound param
nl_ub; # upper bound param
u0=new_param,# initial guess param
nrep =5,
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=7,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="L2", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=50,
maxiters=9000000,
abstol=0.000000001,
thr_lowess=0.05,
penality_CI = 8
)

plot(M[3])

histogram(M[3])
new_param = [M[1][3],M[1][4],M[1][5],M[1][6]]

B1= fit_NL_model(data_OD_smooth2, # dataset first row times second row OD
"test", # name of the well
"", #label of the experiment
"NL_Bertalanffy", # ode model to use
nl_lb, # lower bound param
nl_ub; # upper bound param
u0=new_param,# initial guess param
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=7,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="L2_fixed_CI", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=200,
maxiters=9000000,
abstol=0.000000000001,
thr_lowess=0.05,
penality_CI = 4
)

@time  C = fit_NL_model_with_sensitivity(data_OD_smooth2, # dataset first row times second row OD
"", # name of the well
"", #label of the experiment
"NL_Bertalanffy", # ode model to use
nl_lb, # lower bound param
nl_ub; # upper bound param
nrep=100,
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=0,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="L2", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=50,
maxiters=90000000,
abstol=0.00000001,
thr_lowess=0.05,
penality_CI = 9
)

@time  D = fit_NL_model_bootstrap(data_OD_smooth2, # dataset first row times second row OD
"", # name of the well
"", #label of the experiment
"NL_Bertalanffy", # ode model to use
nl_lb, # lower bound param
nl_ub; # upper bound param
nrep=500,
u0=[00.01, 0.01,0.01,1.01],# initial guess param
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=7,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="RE", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=50,
maxiters=2000000,
abstol=0.000000001,
thr_lowess=0.05,
)



nl_ub_1 =  [2.0001 , 10.00000001, 500.00]
nl_lb_1 =  [0.0001 , 0.00000001, 0.00 ]

nl_ub_2 =  [2.0001 , 10.00000001, 5.00,5.0]
nl_lb_2 =  [0.0001 , 0.00000001, 0.00,0.0 ]

nl_ub_3 =  [2.0001 , 10.00000001]
nl_lb_3 =  [0.0001 , 0.00000001]

nl_ub_4 =  [2.0001 , 10.00000001, 500.00]
nl_lb_4 =  [0.0001 , 0.00000001, 0.00 ]

list_models_f = ["NL_Gompertz","NL_Bertalanffy","NL_exponential","NL_Gompertz"]
list_lb =[nl_lb_1,nl_lb_2,nl_lb_3,nl_lb_4]
list_ub = [nl_ub_1,nl_ub_2,nl_ub_3,nl_ub_4]

@time H= NL_model_selection(data_OD_smooth2, # dataset first row times second row OD
"", # name of the well
"test", #label of the experiment
list_models_f, # ode model to use
list_lb, # lower bound param
list_ub; # upper bound param
method_of_fitting="MCMC",
nrep=5,
list_u0=list_lb .+ (list_ub .- list_lb) ./ 2,# initial guess param
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
size_bootstrap=0.7,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=7,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="L2_fixed_CI", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=50,
maxiters=2000000,
abstol=0.0000001,
thr_lowess=0.05,
write_res=false,
beta_param=2.0,
penality_CI=8.0
)



nl_ub_1 =  [2.0001 , 10.00000001, 500.00]
nl_lb_1 =  [0.0001 , 0.00000001, 0.00 ]

nl_ub_2 =  [2.0001 , 10.00000001, 5.00,5.0]
nl_lb_2 =  [0.0001 , 0.00000001, 0.00,0.0 ]

nl_ub_3 =  [2.0001 , 10.00000001]
nl_lb_3 =  [0.0001 , 0.00000001]

nl_ub_4 =  [2.0001 , 10.00000001, 500.00]
nl_lb_4 =  [0.0001 , 0.00000001, 0.00 ]

list_models_f = ["NL_Gompertz","NL_Bertalanffy","NL_exponential","NL_logistic"]
list_lb =[nl_lb_1,nl_lb_2,nl_lb_3,nl_lb_4]
list_ub = [nl_ub_1,nl_ub_2,nl_ub_3,nl_ub_4]

data_OD = Matrix(transpose(hcat(unique(data_OD[1,:]),unique(data_OD[2,1:length(unique(data_OD[1,:]))]))))
scatter(data_OD[1,:],data_OD[2,:])

collect(combinations([1,2,3,4,5,6], 3))
R= selection_NL_maxiumum_change_points(
    data_OD, # dataset first row times second row OD
    "", # name of the well
    "test", #label of the experiment
    list_models_f, # ode model to use
    list_lb, # lower bound param
    list_ub, # upper bound param
    3;
    type_of_loss="L2", # type of used loss
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method
    method_of_fitting="MCMC", # selection of sciml integrator
    type_of_detection="sliding_win",
    type_of_curve="original",
    smoothing=true,
    type_of_smoothing="lowess",
    thr_lowess=0.05,
    detect_number_cpd= true,
    fixed_cpd= false,
    pt_avg=1,
    nrep=10,
    save_plot=false, # do plots or no
    display_plots=true,
    path_to_plot="NA", # where save plots
    win_size=10, # numebr of the point to generate intial condition
    pt_smooth_derivative=0,
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    method_multiple_scattering_correction="interpolation",
    calibration_OD_curve="NA", #  the path to calibration curve to fix the data
    beta_smoothing_ms= 2.0, #  parameter of the AIC penality
    method_peaks_detection="peaks_prominence",
    PopulationSize=50,
    maxiters=2000000,
    abstol=0.000000001,
    penality_CI =6.0,
    correction_AIC = false
)





xdata =data_OD[1,:]
ydata = data_OD[2,:]
p0 = [10.1, 10.1,10.1,10.1,10.1]
NL_model_Richards(x,p) = p[1] ./ (1 .+ p[2] .* exp.( .- p[3] .* ( x .- p[4] ))).^(1. ./ p[5])
fit = LsqFit.curve_fit(NL_model_Richards, data_OD_smooth2[1,:], data_OD_smooth2[2,:], p0)
sol = NL_model_Richards( data_OD_smooth2[1,:] , fit.param )
plot!(data_OD_smooth2[1,:],sol)


results = fitting_one_well_custom_ODE(data_OD_smooth2, # dataset first row times second row OD
"test", # name of the well
"test_model_custom", #label of the experiment
ODE_custom, # ode model to use 
custom_lb, # lower bound param
custom_ub, # upper bound param
2; # number ode in the system
display_plots=true, # do plots or no
path_to_plot=path_to_plotting, # where save plots
maxiters = 20,
)

# testing sensitivity
n_step_sensitivity = 3

sensitivity_test = one_well_morris_sensitivity(data_OD_smooth2, # dataset first row times second row OD
    "test", # name of the well
    "test_sensitivity", #label of the experiment
    "aHPM", # ode model to use 
    lb_dhpm, # lower bound param
    ub_dhpm; # upper bound param
    N_step_morris =n_step_sensitivity,
    maxiters = 30)
# testing model selection



ub_piece_wise_logistic =[ 0.06 , 2.0 , 500.0 , 10.0 ,  0.001    ]
lb_piece_wise_logistic =[ 0.0001 , 0.001,0.0  , 0.001 ,  - 0.001  ]

ub_baranyi_roberts =[ 0.06 , 2.0 , 500.0 , 10.0,  10   ]
lb_baranyi_roberts =[ 0.0001 , 0.001, 0.0 ,  0.01 , 0  ]



ub_triple_exp =[ 1.2 , 0.001 ,  0.2 , 500.0  , 2000   ]
lb_triple_exp =[ 0.0001 , -0.001, 0.0  , 00.0 ,  200.0   ]



ub_dhpm =[ 1.2 , 1.1 , 4.0  ,20  ]
lb_dhpm =[ 0.0001 , 0.00000001, 0.00 ,0 ]

ub_exp=[1.0]
lb_exp= [-0.001]
list_of_models = ["aHPM","piecewise_adjusted_logistic","exponential"]
list_ub =[ub_dhpm  , ub_piece_wise_logistic  ,ub_exp ];
list_lb =[lb_dhpm , lb_piece_wise_logistic   ,lb_exp];




results_ms = ODE_Model_selection(data_OD_smooth2, # dataset first row times second row OD
"test", # name of the well
"test_model_selection", #label of the experiment
list_of_models, # ode model to use 
list_lb, # lower bound param
list_ub; # upper bound param
display_plot_best_model = true,
save_plot_best_model=false, # one wants the results of the best fit to be plotted
verbose=true,
maxiters = 3000000,
beta_penality=1.0, # penality for AIC evaluation
correction_AIC= false
)





results_ms[1]



# now i show one of the segmentation fitting
# first i generate a dataset with a sequence of ODEs

# first segment ODE

model = "logistic"
n_start =[0.1]
tstart =0.0

tmax = 0100.0
delta_t=2.0
param_of_ode= [0.1,0.2
]
sim_1 = ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)

sol_1 =reduce(vcat,sim_1)

# second segment ODE


model = "logistic"
n_start =[sol_1[end]]
tstart =100.0
tmax = 0200.0
delta_t=2.0
param_of_ode= [0.2,0.5
]


sim_2= ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)

sol_2 =reduce(vcat,sim_2)
# third segment ODE


model = "logistic"
n_start =[sol_2[end]]
tstart =200.0
tmax = 0300.0
delta_t=2.0
param_of_ode= [0.1,0.9
]
sim_3= ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)

sol_3 =reduce(vcat,sim_3)
times_sim =vcat(sim_1.t,sim_2.t)
times_sim =vcat(times_sim,sim_3.t)

# binding the simulatios
sol_sim =vcat(sol_1,sol_2)
sol_sim =vcat(sol_sim,sol_3)


Plots.scatter(sol_sim, xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:blue, size = (300,300))

Plots.scatter(sol_sim[40:60], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:blue, size = (300,300))


data_OD = Matrix(transpose(hcat(times_sim,sol_sim)))

cpd_lsdd_profile(data_OD,2)

deriv = specific_gr_evaluation(data_OD,17 )
Plots.scatter(deriv, xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:blue, size = (300,300))




profile = ChangePointDetection.lsdd_profile(deriv; window = 2)
Plots.scatter(profile, xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:blue, size = (300,300))


ChangePointDetection.changepoints(deriv; threshold = mean(profile), window = 2)
ChangePointDetection.changepoints(data_OD; threshold = mean(profile), window = 2)
uuu = curve_dissimilitary_lin_fitting(data_OD,1,7)
plot(uuu[1,:],uuu[2,:])
profile = convert.(Float64,profile)
data_dissim = Matrix(transpose(hcat(data_OD[1,1:length(profile)], profile)))

pks, vals = findmaxima(data_dissim[2,:]; strict=true)
pks, proms = peakproms(pks, data_dissim[2,:])
pks, widths, leftedge, rightedge = peakwidths(pks, data_dissim[2,:], proms)

selected_change_point_index = peaks_detection(data_dissim,2)

Plots.vline!(selected_change_point_index[1], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:red, size = (300,300))


#adding noise_unifo
noise_unifom = rand(Uniform(-0.01,0.01),length(sol_sim))


data_OD = Matrix(transpose(hcat(times_sim,sol_sim)))
data_OD[2,:] = data_OD[2,:] .+ noise_unifom
Plots.scatter(data_OD[1,:],data_OD[2,:], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],color=:blue,markersize =2 ,size = (300,300))
# testing change point function 

# inizialixating all the models
ub_exp =[ 0.1 ]
lb_exp =[ -00.01 ]
                
ub_logistic =[ 0.9 , 5.0]
lb_logistic =[ 0.0001 , 0.001]
                
ub_hpm =[ 0.1 , 20.0 , 50.001  ]
lb_hpm =[ 0.0001 , 0.000001, 0.001  ]
                
ub_hpm_exp = [ 0.1 , 20.0   ]
lb_hpm_exp = [ 0.0001 , 0.0000001  ]

list_of_models = ["exponential","HPM","HPM_exp","logistic"]#,"dHPM"]
list_ub_param =[ub_exp,ub_hpm,ub_hpm_exp,ub_logistic]#,ub_dhpm]# , ub_triple_exp ,ub_baranyi_roberts  ];
list_lb_param =[lb_exp,lb_hpm,lb_hpm_exp,lb_logistic]#,lb_dhpm]
                



# fitting with a fixed number of change points

test_fixed_cdp =selection_ODE_fixed_change_points(data_OD, # dataset first row times second row OD
"test", # name of the well
"test", #label of the experiment
list_of_models, # ode models to use 
list_lb_param, # lower bound param
list_ub_param, # upper bound param
3; # number of change_points
display_plots=true, # do plots or no
path_to_plot="", # where save plots
pt_smooth_derivative = 0,
maxiters = 300
) 













# testing custom ode

# function of the custom ODE


"
Start of the test for the functions that do a complete file

"
path_to_plot = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/new_test/plots/"
path_to_results = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/new_test/res/"
path_to_data  = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/LG110/data_channel_1.csv"
path_to_annotation  = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/LG110/annotation_channel_1.csv"

include(string(path_to_functions,"/functions.jl"))


plot_data(
   "test", #label of the experiment
    path_to_data, # path to the folder to analyze
    path_to_annotation;# path to the annotation of the wells
    path_to_plot = "NA", # path where to save Plots
    display_plots = true,# display plots in julia or not
    save_plots = false, # save the plot or not
    overlay_plots = true, # true a single plot for all dataset false one plot per well
    do_blank_subtraction = "NO", # string on how to use blank (NO,avg_subtraction,time_avg)
    avg_replicate = false, # if true the average between replicates
    correct_negative = "thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
    thr_negative = 0.01,  # used only if correct_negative == "thr_correction"
)

path_calib = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/scripts_for_figures/Example/data_example/ms_cal.csv"

fitting_log_line_test = fit_one_file_Log_Lin(
    "", #label of the experiment
    path_to_data, # path to the folder to analyze
    path_to_annotation;# path to the annotation of the wells
    path_to_results="NA",# path where save results
    path_to_plot="NA",# path where to save Plots
    display_plots=true,# display plots in julia or not
    save_plots=false, # save the plot or not    verbose=false, # 1 true verbose
    write_res=false, # write results
    type_of_smoothing="rolling_avg", # option, NO, gaussian, rolling avg
    pt_avg=7, # number of points to do smoothing average
    pt_smoothing_derivative=7, # number of poits to smooth the derivative
    pt_min_size_of_win=7, # minimum size of the exp windows in number of smooted points
    type_of_win="maximum", # how the exp. phase win is selected, "maximum" of "global_thr"
    threshold_of_exp=0.9, # threshold of growth rate in quantile to define the exp windows
    do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
    avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
    correct_negative="thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
    thr_negative=0.01, # used only if correct_negative == "thr_correction"
    multiple_scattering_correction=true, # if true uses the given calibration curve to fix the data
    calibration_OD_curve=path_calib, #  the path to calibration curve to fix the data
    thr_lowess=0.05, # keyword argument of lowees smoothing
)

model = "HPM"
lb_param = [0.0,0.0,0.0]
ub_param = [2.0,2.0,2.0]

fitting_ode_file_test = fit_file_ODE(
    "", #label of the experiment
    path_to_data, # path to the folder to analyze
    path_to_annotation,# path to the annotation of the wells
    model, # string of the used model
    lb_param,# array of the array of the lower bound of the parameters
    ub_param; # array of the array of the upper bound of the parameters
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
    integrator=KenCarp4(autodiff=true), # selection of sciml integrator
    path_to_results="NA", # path where save results
    path_to_plot="NA", # path where to save Plots
    loss_type="L2_log", # string of the type of the used loss
    smoothing=true, # 1 do smoothing of data with rolling average
    type_of_smoothing="lowess",
    display_plots=true,# display plots in julia or not
    save_plots=false,
    verbose=false, # 1 true verbose
    write_res=false, # write results
    pt_avg=1, # number of points to do smoothing average
    pt_smooth_derivative=7, # number of points to do ssmooth_derivative
    do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
    avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
    correct_negative="removal", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
    thr_negative=0.01,  # used only if correct_negative == "thr_correction"
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
    PopulationSize=30,
    maxiters=20,
    abstol=0.00001,
    thr_lowess=0.05,
)

function ODE_custom(du, u, param, t)

    du[1] =  u[1] * (1 - u[1] )* (param[2])  +  param[1] *  u[1] 

    du[2] = + u[1] * (param[2]) + param[4] * u[2]* ( 1 - (u[1] + u[2])/param[3]) 

    
end

custom_ub = [ 1.2 , 1.1 , 2.0  ,20  ]

custom_lb=[ 0.0001 , 0.00000001, 0.00 ,0 ]


fitting_ode_custom_test = fit_file_custom_ODE(
    "test", #label of the experiment
    path_to_data, # path to the folder to analyze
    path_to_annotation,# path to the annotation of the wells
    ODE_custom, # string of the used model
    custom_lb,# array of the array of the lower bound of the parameters
    custom_ub, # array of the array of the upper bound of the parameters
    2;
    optmizator =   BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
    integrator = KenCarp4(autodiff=true), # selection of sciml integrator
    path_to_results=path_to_results, # path where save results
    path_to_plot=path_to_plot, # path where to save Plots
    loss_type="RE", # string of the type of the used loss
    smoothing=true, # 1 do smoothing of data with rolling average
    type_of_smoothing ="lowess",
    display_plots=true ,# display plots in julia or not
    save_plots=false,
    verbose=false, # 1 true verbose
    write_res=true, # write results
    pt_avg=1, # number of points to do smoothing average
    pt_smooth_derivative=7, # number of points to do ssmooth_derivative
    do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
    avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
    correct_negative="thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
    thr_negative=0.01,  # used only if correct_negative == "thr_correction"
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
    PopulationSize = 30,
    maxiters = 20,
     abstol = 0.00001,
     thr_lowess = 0.01) 



# inizialixating all the models
ub_piece_wise_logistic =[ 0.06 , 2.0 , 500.0 , 10.0 ,  0.001    ]
lb_piece_wise_logistic =[ 0.0001 , 0.001,0.0  , 0.001 ,  - 0.001  ]

ub_baranyi_roberts =[ 0.06 , 2.0 , 500.0 , 10.0,  10   ]
lb_baranyi_roberts =[ 0.0001 , 0.001, 0.0 ,  0.01 , 0  ]



ub_triple_exp =[ 1.2 , 0.001 ,  0.2 , 500.0  , 2000   ]
lb_triple_exp =[ 0.0001 , -0.001, 0.0  , 00.0 ,  200.0   ]



ub_dhpm =[ 1.2 , 1.1 , 2.0  ,20  ]
lb_dhpm =[ 0.0001 , 0.00000001, 0.00 ,0 ]



list_of_models = ["aHPM","piecewise_adjusted_logistic"]
list_ub =[ub_dhpm  , ub_piece_wise_logistic   ];
list_lb =[lb_dhpm , lb_piece_wise_logistic   ];

            

fitting_model_selection_test = ODE_model_selection_file(
   "test", #label of the experiment
    path_to_data, # path to the folder to analyze
    path_to_annotation,# path to the annotation of the wells
    list_of_models, # ode model to use 
    list_lb, # lower bound param
    list_ub; # upper bound param
    optmizator =   BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
    integrator = KenCarp4(autodiff=true), # selection of sciml integrator
    path_to_results=path_to_results, # path where save results
    path_to_plot=path_to_plot, # path where to save Plots
    loss_type="L2", # string of the type of the used loss
    smoothing=true, # 1 do smoothing of data with rolling average
    type_of_smoothing ="lowess",
    display_plot_best_model=true, # one wants the results of the best fit to be plotted
    save_plot_best_model=true,
    beta_penality = 2.0, # penality for AIC evaluation
    verbose=true, # 1 true verbose
    write_res=true, # write results
    pt_avg=1, # number of points to do smoothing average
    pt_smooth_derivative=7, # number of points to do ssmooth_derivative
    avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
    correct_negative="thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
    thr_negative=0.01,  # used only if correct_negative == "thr_correction"
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
    PopulationSize = 30,
    maxiters = 200,
     abstol = 0.00001,
     thr_lowess = 0.05) 



A = selection_ODE_fixed_change_points_file(
    "test", #label of the experiment
    path_to_data, # path to the folder to analyze
    path_to_annotation,# path to the annotation of the wells
    list_of_models, # ode model to use 
    list_lb, # lower bound param
    list_ub,# upper bound param
    4; 
    optmizator =   BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
    integrator = KenCarp4(autodiff=true), # selection of sciml integrator
    type_of_loss="L2", # type of used loss 
    type_of_detection =  "sliding_win",
    type_of_curve = "original", 
    pt_avg = 1 , # number of the point to generate intial condition
    smoothing= true, # the smoothing is done or not?
    save_plots=false, # do plots or no
    display_plots=true, # do plots or no
    path_to_plot="NA", # where save plots
    path_to_results="NA",
    win_size=8, 
    pt_smooth_derivative=0,
    penality_parameter=0.0,
    multiple_scattering_correction="false", # if true uses the given calibration curve to fix the data
    calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
    write_res =false ,
    method_peaks_detection= "peaks_prominence",
    bins = 40,
   PopulationSize = 30,
    maxiters = 200,
    abstol = 0.00001,
    type_of_smoothing = "lowess" ,
    thr_lowess = 0.05
    )


nl_ub_1 =  [2.0001 , 10.00000001, 5000.00]
nl_lb_1 =  [0.0001 , 0.00000001, 0.00 ]
    
nl_ub_2 =  [2.0001 , 10.00000001, 5.00,5.0]
nl_lb_2 =  [0.0001 , 0.00000001, 0.00,0.0 ]
    
nl_ub_3 =  [2.0001 , 10.00000001]
nl_lb_3 =  [0.0001 ,- 1.10000001]
    
nl_ub_4 =  [2.0001 , 10.00000001, 500.00]
nl_lb_4 =  [0.0001 , 0.00000001, 0.00 ]

list_models_f = ["NL_Gompertz","NL_Bertalanffy","NL_exponential","NL_logistic"]
list_lb =[nl_lb_1,nl_lb_2,nl_lb_3,nl_lb_4]
list_ub = [nl_ub_1,nl_ub_2,nl_ub_3,nl_ub_4]

path_to_plot = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/new_test/plots_LG119/"
path_to_results = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/new_test/res_LG119/"
path_to_data  = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/LG119/data_channel_1.csv"
path_to_annotation  = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/LG119/annotation_channel_1.csv"


K=  fit_NL_model_file(
        "", #label of the experiment
        path_to_data, # path to the folder to analyze
        path_to_annotation,# path to the annotation of the wells
        "NL_Gompertz", # ode model to use
        nl_lb_1, # lower bound param
        nl_ub_1;
        method_of_fitting="Bootstrap",
        nrep=5,
        u0=nl_lb_1 .+ (nl_ub_1 .- nl_lb_1) ./ 2,# initial guess param
        optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
        path_to_results="NA", # path where save results
        path_to_plot="NA", # path where to save Plots
        loss_type="RE", # string of the type of the used loss
        smoothing=true, # 1 do smoothing of data with rolling average
        type_of_smoothing="lowess",
        errors_estimation = true,
        display_plots=true,# display plots in julia or not
        save_plots=false,
        write_res=false, # write results
        pt_avg=1, # number of points to do smoothing average
        pt_smooth_derivative=0, # number of points to do ssmooth_derivative
        do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
        avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
        correct_negative="thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
        thr_negative=0.01,  # used only if correct_negative == "thr_correction"
        multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
        method_multiple_scattering_correction="interpolation",
        calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
        PopulationSize=100,
        maxiters=2000000,
        abstol=0.00001,
        thr_lowess=0.05,
        penality_CI=4.0,
        verbose =false,

    
)
K=  fit_NL_segmentation_file(
        "", #label of the experiment
        path_to_data, # path to the folder to analyze
        path_to_annotation,# path to the annotation of the wells
        list_models_f, # ode model to use
        list_lb, # lower bound param
        list_ub, # upper bound param
        4;
        method_of_fitting="Bootstrap",
        nrep=5,
        list_u0=list_lb .+ (list_ub .- list_lb) ./ 2,# initial guess param
        optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
        path_to_results="NA", # path where save results
        path_to_plot="NA", # path where to save Plots
        loss_type="RE", # string of the type of the used loss
        smoothing=true, # 1 do smoothing of data with rolling average
        type_of_smoothing="lowess",
        display_plots=true,# display plots in julia or not
        save_plots=false,
        write_res=false, # write results
        pt_avg=1, # number of points to do smoothing average
        pt_smooth_derivative=0, # number of points to do ssmooth_derivative
        do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
        avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
        correct_negative="thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
        thr_negative=0.01,  # used only if correct_negative == "thr_correction"
        multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
        method_multiple_scattering_correction="interpolation",
        calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
        PopulationSize=100,
        maxiters=2000000,
        abstol=0.00001,
        thr_lowess=0.05,
        detect_number_cdp= false,
        fixed_cpd = true,
        penality_CI=4.0,
        beta_smoothing_ms = 2.0,
        verbose =false,
        win_size=14, # number of the point of cpd sliding win

    
)
    















model = "exponential"
n_start =[0.1]
tstart =0.0

tmax = 0100.0
delta_t=2.0
param_of_ode= [0.01
]
sim_1 = ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)

sol_1 =reduce(vcat,sim_1)

# second segment ODE
n_start =[sol_1[end]]
tstart =102.0

tmax = 0200.0
delta_t=2.0
param_of_ode= [-0.01
]
sim_2 = ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)

sol_2 =reduce(vcat,sim_2)

model = "logistic"
n_start =[sol_2[end]]
tstart =202.0
tmax = 0300.0
delta_t=2.0
param_of_ode= [00.2,0.5
]


sim_3= ODE_sim(model, #string of the model
    n_start, # starting condition
    tstart, # start time of the sim
    tmax, # final time of the sim
    delta_t, # delta t for poisson approx
    param_of_ode # parameters of the ODE model
)

sol_3 =reduce(vcat,sim_3)
# third segment ODE


times_sim =vcat(sim_1.t,sim_2.t)
times_sim =vcat(times_sim,sim_3.t)

# binding the simulatios
sol_sim =vcat(sol_1,sol_2)
sol_sim =vcat(sol_sim,sol_3)




Plots.scatter(sol_sim, xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],  color=:blue, size = (300,300))



data_OD = Matrix(transpose(hcat(times_sim,sol_sim)))

#adding noise_unifo
noise_unifom = rand(Uniform(-0.001,0.001),length(sol_sim))

data_OD[2,:] = data_OD[2,:] .+ noise_unifom
Plots.scatter(data_OD[1,:],data_OD[2,:], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],color=:blue,markersize =2 ,size = (300,300))
# testing change point function 


L = selection_NL_fixed_interval(
    data_OD, # dataset first row times second row OD
    "", # name of the well
   "", #label of the experiment
   ["NL_logistic","NL_exponential"], # ode models to use
   [[0.0,0.0,-1.0],[0.0,-0.1]], # upper bound param
   [[1.0,1.0,100000.0],[1.0,1.0]],
   [100,200];
    list_u0=[[0.001,0.99,00.5],[0.9001,0.91]],# initial guess param
    type_of_loss="L2", # type of used loss
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method
    method_of_fitting="single", # selection of sciml integrator
    smoothing=false,
    nrep =20,
    type_of_smoothing="lowess",
    thr_lowess=0.05,
    pt_avg=1,
    pt_smooth_derivative=0,
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    method_multiple_scattering_correction="interpolation",
    calibration_OD_curve="NA", #  the path to calibration curve to fix the data
    beta_smoothing_ms=2.0, #  parameter of the AIC penality
    PopulationSize=500,
    maxiters=20000000,
    abstol=0.000000001,
    penality_CI=80000000.0)

    Plots.scatter(data_OD[1,:],data_OD[2,:], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],color=:blue,markersize =2 ,size = (300,300))

    plot!(L[3],L[2])

    data_OD_1 = Matrix(transpose(hcat(sim_3.t,sol_3)))

    #adding noise_unifo
    noise_unifom = rand(Uniform(-0.001,0.001),length(sim_3.t))
    
    data_OD_1[2,:] = data_OD_1[2,:] .+ noise_unifom
    Plots.scatter(data_OD_1[1,:],data_OD_1[2,:], xlabel="Time", ylabel="Arb. Units", label=["Data " nothing],color=:blue,markersize =2 ,size = (300,300))
    # testing change point function 
a,b = remove_replicate_data(L[3], L[2])



@time H_1 = fit_NL_model_with_sensitivity(data_OD_1, # dataset first row times second row OD
"", # name of the well
"test", #label of the experiment
"NL_logistic", # ode models to use
[0.0,0.0,-1.0], # upper bound param
[1.0,1.0,10000.0];
nrep=500,
optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
display_plots=true, # display plots in julia or not
save_plot=false,
path_to_plot="NA", # where save plots
pt_avg=1, # numebr of the point to generate intial condition
pt_smooth_derivative=7,
smoothing=false, # the smoothing is done or not?
type_of_smoothing="rolling_avg",
type_of_loss="RE", # type of used loss
multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
method_multiple_scattering_correction="interpolation",
calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
PopulationSize=50,
maxiters=20000000,
abstol=0.0000001,
thr_lowess=0.05,
write_res=false,
penality_CI=80000000.0
)


Plots.scatter(H_1[3][3,2:end], xlabel="Hyper param configuration", ylabel="P1", label=[ nothing],color=:blue,markersize =2 ,size = (300,300))
Plots.scatter(H_1[3][4,2:end], xlabel="Hyper param configuration", ylabel="P2", label=[ nothing],color=:blue,markersize =2 ,size = (300,300))
Plots.scatter(H_1[3][5,2:end], xlabel="Hyper param configuration", ylabel="P3", label=[ nothing],color=:blue,markersize =2 ,size = (300,300))
lb =[0.0,0.0,-1.0] # upper bound param
 ub =  [1.0,1.0,10000.0]
 mc_res = Any
initial_u0=[  rand(Uniform(lb[s],ub[s]))[1] for s in 1:length([0.0,0.0,-1.0])]
 for i in 1:200
    initial_u0=[  rand(Uniform(lb[s],ub[s]))[1] for s in 1:length([0.0,0.0,-1.0])]

   mcmc = fit_NL_model_MCMC_intialization(data_OD_1, # dataset first row times second row OD
   "", # name of the well
   "test", #label of the experiment
   "NL_logistic", # ode models to use
   lb, # upper bound param
   ub;
    u0= initial_u0 ,
    nrep=10,
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(),
    display_plots=true, #  display plots in julia or not
    save_plot=false,
    path_to_plot="NA", # where save plots
    pt_avg=1, # numebr of the point to generate intial condition
    pt_smooth_derivative=7,
    smoothing=false, # the smoothing is done or not?
    type_of_smoothing="rolling_avg",
    type_of_loss="RE", # type of used loss
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    method_multiple_scattering_correction="interpolation",
    calibration_OD_curve="NA",  #  the path to calibration curve to fix the data
    PopulationSize=300,
    maxiters=2000000,
    abstol=0.00001,
    thr_lowess=0.05,
    penality_CI=3.0,
)
    if i == 1

     mc_res =mcmc[1]

        else
            mc_res =hcat(mc_res,mcmc[1])

        end 

    
end   




Plots.scatter(mc_res[3,1:end], xlabel="Hyper param configuration", ylabel="P1", label=[ nothing],color=:blue,markersize =2 ,size = (300,300))
Plots.scatter(mc_res[4,1:end], xlabel="Hyper param configuration", ylabel="P2", label=[ nothing],color=:blue,markersize =2 ,size = (300,300))
Plots.scatter(mc_res[5,1:end], xlabel="Hyper param configuration", ylabel="P3", label=[ nothing],color=:blue,markersize =2 ,size = (300,300))








path_to_data  = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/LG119/data_channel_1.csv"
path_to_annotation  = "/Users/fabrizio.angaroni/Documents/J-MAKi.jl-main.jl/example_for_fernanda/LG119/annotation_channel_1.csv"

model_list_ODE= ["logistic","exponential","gompertz"]
model_list_NL= ["NL_logistic","NL_exponential","NL_Gompertz"]

ode_lb_logistic = [0.01, 0.0]
ode_ub_logistic = [0.1, 2.5]


ode_lb_exp = [-0.01]
ode_ub_exp = [0.1]

ode_lb_gompertz = [0.01, 0.3]
ode_ub_gompertz = [0.1, 2.5]



NL_lb_logistic = [0.0, 0.01, -1200]
NL_ub_logistic = [2.5, 0.1, +1200]

NL_lb_exp= [0.0, - 0.01]
NL_ub_exp = [2.5, 0.1]


NL_lb_gompertz = [0.0, 0.01, -1200]
NL_ub_gompertz = [2.5, 0.1, +1200]

list_lb_ODE =[ode_lb_logistic,ode_lb_exp,ode_lb_gompertz]
list_ub_ODE =[ode_ub_logistic,ode_ub_exp,ode_ub_gompertz]

list_lb_NL =[NL_lb_logistic,NL_lb_exp,NL_lb_gompertz]
list_ub_NL =[NL_ub_logistic,NL_ub_exp,NL_ub_gompertz]



data_1 = CSV.File(path_to_data);
# 
names_of_cols = propertynames(data_1);
data_temp = data_1[names_of_cols[1]];
times_data= convert(Vector{Float64}, data_temp)

data_OD =    Matrix(transpose(hcat(times_data, data_1[names_of_cols[4]])));

plot(data_OD[1,:],data_OD[2,:])



segment_intervals = [250.0]


ODE_fit = selection_ODE_fixed_intervals(
    data_OD, # dataset first row times second row OD
    "", # name of the well
    "", #label of the experiment
    model_list_ODE, # ode models to use
    list_lb_ODE, # lower bound param
    list_ub_ODE, # upper bound param
    segment_intervals;
    type_of_loss="RE", # type of used loss
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method
    integrator=Tsit5(), # selection of sciml integrator
    smoothing=false,
    type_of_smoothing="lowess",
    thr_lowess=0.05,
    pt_avg=1,
    save_plot=false, # do plots or no
    display_plots=true,
    path_to_plot="NA", # where save plots
    pt_smooth_derivative=0,
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    method_multiple_scattering_correction="interpolation",
    calibration_OD_curve="NA", #  the path to calibration curve to fix the data
    beta_smoothing_ms=2.0, #  parameter of the AIC penality
    PopulationSize=300,
    maxiters=2000000,
    abstol=0.0000000001,
)



ODE_fit[1]

u0_NL_logistic =[data_OD[2,end],0.00018677420615663637,250.0]
u0_NL_exp =[data_OD[2,1],0.00018677420615663637]
u0_NL_gompertz =[0.6,0.01,250.0]

segment_intervals = [250.0]
NL_fit = selection_NL_fixed_interval(
    data_OD, # dataset first row times second row OD
    "", # name of the well
   "", #label of the experiment
   model_list_NL, # ode models to use
   list_lb_NL, # upper bound param
   list_ub_NL,
   segment_intervals;
    #list_u0=[[0.001,0.99,00.5],[0.9001,0.91]],# initial guess param
    type_of_loss="RE", # type of used loss
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method
    method_of_fitting="single", # selection of sciml integrator
    smoothing=false,
    nrep =10,
    type_of_smoothing="lowess",
    thr_lowess=0.05,
    pt_avg=1,
    pt_smooth_derivative=0,
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    method_multiple_scattering_correction="interpolation",
    calibration_OD_curve="NA", #  the path to calibration curve to fix the data
    beta_smoothing_ms=2.0, #  parameter of the AIC penality
    PopulationSize=500,
    maxiters=20000000,
    abstol=0.000000001,
    penality_CI=2.0)

plot(NL_fit[3],NL_fit[2])


segment_intervals = [250.0]

NL_fit = selection_NL_fixed_interval(
    data_OD, # dataset first row times second row OD
    "", # name of the well
   "", #label of the experiment
   model_list_NL, # ode models to use
   list_lb_NL, # upper bound param
   list_ub_NL,
   segment_intervals;
    #list_u0=[[0.001,0.99,00.5],[0.9001,0.91]],# initial guess param
    type_of_loss="L2", # type of used loss
    optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method
    method_of_fitting="MCMC", # selection of sciml integrator
    smoothing=false,
    nrep =10,
    type_of_smoothing="lowess",
    thr_lowess=0.05,
    pt_avg=1,
    pt_smooth_derivative=0,
    multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    method_multiple_scattering_correction="interpolation",
    calibration_OD_curve="NA", #  the path to calibration curve to fix the data
    beta_smoothing_ms=2.0, #  parameter of the AIC penality
    PopulationSize=500,
    maxiters=20000000,
    abstol=0.000000001,
    penality_CI=2.0)

    plot(NL_fit[3],NL_fit[2])


path_to_data  = "E://Lavoro//Kimchi_utilities-main//real_dataset_tests//dataset//N_max_effect//Yield experiments//LG126//data_channel_1.csv"
path_to_annotation  = "E://Lavoro//Kimchi_utilities-main//real_dataset_tests//dataset//N_max_effect//Yield experiments//LG126//annotation_channel_1.csv"

    ub_exp =[ 1.6 ]
    lb_exp =[ -00.1 ]
    
    ub_logistic =[ 0.9 , 1.001]
    lb_logistic =[ 0.0001 , 0.001]
    
    
    ub_hpm =[ 0.1 , 20 , 50.001  ]
    lb_hpm =[ 0.0001 , 0.000001, 0.001  ]
    
    
    ub_hpm_exp = [ 0.1 , 20   ]
    lb_hpm_exp = [ 0.0001 , 0.0000001  ]
    
    
    ub_dhpm =[ 0.6 , 3, 20.001  ,10.0]
    lb_dhpm =[ 0.0001 , 0.000010, 0.001  ,0.001]
    
    
    list_of_models = ["exponential","HPM","HPM_exp","logistic","aHPM"]
    list_ub_param =[ub_exp,ub_hpm,ub_hpm_exp,ub_logistic,ub_dhpm]
    list_lb_param =[lb_exp,lb_hpm,lb_hpm_exp,lb_logistic,lb_dhpm]
    
    
seg_ODE_res = segmentation_ODE_file(
        "segmented_ODE_LG106", #label of the experiment
        path_to_data, # path to the folder to analyze
        path_to_annotation,# path to the annotation of the wells
        list_of_models, # ode model to use 
        list_lb_param, # lower bound param
        list_ub_param,# upper bound param
        2;
        detect_number_cpd=true,
        fixed_cpd=true,
        optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
        integrator=Tsit5(), # selection of sciml integrator
        type_of_loss="RE", # type of used loss 
        type_of_detection="sliding_win",
        type_of_curve="original",
        do_blank_subtraction="avg_blank",
        correct_negative="remove",
        thr_negative=0.01,
        pt_avg=1, # number of the point to generate intial condition
        smoothing=false, # the smoothing is done or not?
        save_plots=false, # do plots or no
        display_plots=true, # do plots or no
        win_size=7, # numebr of the point to generate intial condition
        pt_smooth_derivative=0,
        penality_parameter=2.0,
        write_res=false,
        save_all_model=false,
        method_peaks_detection="peaks_prominence",
        n_bins=40,
        PopulationSize=50,
        maxiters=20000000,
        abstol=0.00000001,
        )













        model = "NL_Bertalanffy"
        nl_ub = [2.0001, 10.00000001, 5.00, 5.0]
        nl_lb = [0.0001, 0.00000001, 0.00, 0.0]
    

        path_to_data = string("E://Lavoro//Kimchi_utilities-main//real_dataset_tests//dataset//N_max_effect//Yield experiments//LG126//data_channel_1.csv")
        path_to_annotation = string("E://Lavoro//Kimchi_utilities-main//real_dataset_tests//dataset//N_max_effect//Yield experiments//LG126//annotation_channel_1.csv")
    

        path_to_plot = string("E://Lavoro//dose_response_res//plots/Bertalanffy_bootstrap//LG126//")
        path_to_results = string("E://Lavoro//dose_response_res//res/Bertalanffy_bootstrap//LG126//")
        fitting_log_line_test = fit_one_file_Log_Lin(
        string("log_lin_", exp), #label of the experiment
        path_to_data, # path to the folder to analyze
        path_to_annotation;# path to the annotation of the wells
        path_to_results=path_to_results,# path where save results
        path_to_plot=path_to_plot,# path where to save Plots
        display_plots=false,# display plots in julia or not
        save_plots=true, # save the plot or not    verbose=false, # 1 true verbose
        write_res=true, # write results
        type_of_smoothing="rolling_avg", # option, NO, gaussian, rolling avg
        pt_avg=7, # number of points to do smoothing average
        pt_smoothing_derivative=7, # number of poits to smooth the derivative
        pt_min_size_of_win=7, # minimum size of the exp windows in number of smooted points
        type_of_win="maximum", # how the exp. phase win is selected, "maximum" of "global_thr"
        threshold_of_exp=0.9, # threshold of growth rate in quantile to define the exp windows
        do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
        avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
        correct_negative="remove", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
        multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    )




exp ="LG126"

    path_to_data = string("E://Lavoro//Kimchi_utilities-main//real_dataset_tests//dataset//N_max_effect//Yield experiments//", exp, "//data_channel_1.csv")
    path_to_annotation = string("E://Lavoro//Kimchi_utilities-main//real_dataset_tests//dataset//N_max_effect//Yield experiments//", exp, "//annotation_channel_1.csv")

    path_to_plot = string("E://Lavoro//dose_response_res//plots/log_lin//", exp, "//")
    path_to_results = string("E://Lavoro//dose_response_res//res/log_lin//", exp, "//")

    fitting_log_line_test = fit_one_file_Log_Lin(
        string("log_lin_", exp), #label of the experiment
        path_to_data, # path to the folder to analyze
        path_to_results=path_to_results,# path where save results
        path_to_plot=path_to_plot,# path where to save Plots 
        display_plots=true,# display plots in julia or not
        save_plots=false, # save the plot or not    verbose=false, # 1 true verbose
        write_res=true, # write results
        type_of_smoothing="rolling_avg", # option, NO, gaussian, rolling avg
        pt_avg=7, # number of points to do smoothing average
        pt_smoothing_derivative=7, # number of poits to smooth the derivative
        pt_min_size_of_win=7, # minimum size of the exp windows in number of smooted points
        type_of_win="maximum", # how the exp. phase win is selected, "maximum" of "global_thr"
        threshold_of_exp=0.9, # threshold of growth rate in quantile to define the exp windows
        do_blank_subtraction="NA", # string on how to use blank (NO,avg_subtraction,time_avg)
        avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
        correct_negative="thr_correction", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
        multiple_scattering_correction=false, # if true uses the given calibration curve to fix the data
    )








#list_of_experiments = ["LG106", "LG110", "LG114", "LG115", "LG117", "LG118", "LG119"]
path_to_annotation = string("E:/Lavoro/Kimchi_utilities-main/real_dataset_tests/dataset/data_isolate_chem_mixture_clean/annotation.csv")

path_to_data0 = "E:/Lavoro/Kimchi_utilities-main/real_dataset_tests/dataset/data_isolate_chem_mixture_clean/clean_data/"
list_of_data_chem = readdir(path_to_data0)

for plate in list_of_data_chem
    println(plate)
    path_to_data = string(path_to_data0,plate)
    temp_name = convert(String,split(plate, ".")[1])
    path_to_plot = string("E://Lavoro//chem_isolates//plots//Segmented_NL//", temp_name, "//")
    path_to_results = string("E://Lavoro//chem_isolates//res//Segmented_NL//", temp_name, "//")

 
    nl_ub_1 = [2.0001, 10.00000001, 5.00, 500000.0]
    nl_lb_1 = [0.0001, 0.00000001, 0.00, 0.0]

    nl_ub_2 = [2.0001, 10.00000001, 5.00, 5.0]
    nl_lb_2 = [0.0001, 0.00000001, 0.00, 0.0]

    nl_ub_3 = [2.0001, 10.00000001]
    nl_lb_3 = [0.0001, -1.10000001]

    nl_ub_4 = [2.0001, 10.00000001, 500.00]
    nl_lb_4 = [0.0001, 0.00000001, 0.00]

    list_models_f = ["NL_Richards",  "NL_exponential", "NL_logistic"]
    list_lb = [nl_lb_1,  nl_lb_3, nl_lb_4]
    list_ub = [nl_ub_1,  nl_ub_3, nl_ub_4]


    K = fit_NL_segmentation_file(
        string("segmented_NL_", temp_name), #label of the experiment
        path_to_data, # path to the folder to analyze
        list_models_f, # ode model to use
        list_lb, # lower bound param
        list_ub, # upper bound param
        4;
        path_to_annotation= path_to_annotation,# path to the annotation of the wells
        method_of_fitting="MCMC",
        nrep=25,
        list_u0=list_lb .+ (list_ub .- list_lb) ./ 2,# initial guess param
        optmizator=BBO_adaptive_de_rand_1_bin_radiuslimited(), # selection of optimization method 
        path_to_results=path_to_results, # path where save results
        path_to_plot=path_to_plot, # path where to save Plots
        loss_type="RE_fixed_end", # string of the type of the used loss
        smoothing=true, # 1 do smoothing of data with rolling average
        type_of_smoothing="lowess",
        display_plots=true,# display plots in julia or not
        save_plots=true,
        write_res=true, # write results
        pt_avg=0, # number of points to do smoothing average
        pt_smooth_derivative=4, # number of points to do ssmooth_derivative
        do_blank_subtraction="avg_blank", # string on how to use blank (NO,avg_subtraction,time_avg)
        avg_replicate=false, # if true the average between replicates is fitted. If false all replicate are fitted indipendelitly
        correct_negative="remove", # if "thr_correction" it put a thr on the minimum value of the data with blank subracted, if "blank_correction" uses blank distrib to impute negative values
        PopulationSize=50,
        maxiters=30000000,
        abstol=0.0000000001,
        thr_lowess=0.05,
        detect_number_cpd=true,
        fixed_cpd=false,
        penality_CI=5.0,
        beta_smoothing_ms=2.0,
        verbose=false,
        win_size=6, # number of the point of cpd sliding win
    )






end
