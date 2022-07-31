using JuMP, Gurobi, Plots, Statistics

include("data.jl")
global pv_irra = pv_irra
global consumption = consumption

# optim model in Gurobi
model = Model(Gurobi.Optimizer)

# constants
n_years = 1
pv_irr = repeat(pv_irra, n_years*365)
P_C = repeat(consumption, n_years*365)
time = 1:n_years*365*24
n_PV = 0.18
n_B_plus = 0.85
n_B_moins = 0.9
n_B = 0.85
n_G = 0.9
pi_PV = 614
pi_B = 440
pi_G = 1245
pi_D = 23

# variables
@variable(model, C_PV >= 0)
@variable(model, C_G >= 0)
@variable(model, E_B_max >= 0)
@variable(model, P_PV[time] >= 0)
@variable(model, P_D[time] >= 0)
@variable(model, P_B_charge[time] >= 0)
@variable(model, P_B_discharge[time] >= 0)

# objective
@objective(model, Min, pi_PV*C_PV + pi_B*E_B_max + pi_G*C_G + pi_D*sum(P_D))

# constraints 
@constraint(model, [t in time], P_PV[t] + n_G*P_D[t] + P_B_discharge[t] == P_B_charge[t] + P_C[t])
@constraint(model, [t in time], n_G*P_D[t] <= C_G)
@constraint(model, [t in time], P_PV[t] <= n_PV*pv_irr[t]*C_PV )
@constraint(model, P_B_charge[1] == mean(P_B_charge[range(25,length(time),step=24)]))
@constraint(model, [t in 2:n_years*365*24],  sum( (n_B_plus*P_B_charge[i]-P_B_discharge[i]/n_B_moins)*n_B^(t-1-i) for i in (1:t-1) ) <= E_B_max)
@constraint(model, [t in 2:n_years*365*24],  sum( (n_B_plus*P_B_charge[i]-P_B_discharge[i]/n_B_moins)*n_B^(t-1-i) for i in (1:t-1) ) >= 0)

optimize!(model)

# Optimal solution
C_PV = value(C_PV)
E_B_max = value(E_B_max)
C_G = value(C_G)

println("------------ For ", n_years, " years -------------------")
println("------------ PV Capacity [MW] -------------------")
println(C_PV)
println("------------ Battery Capacity [MWh] -------------------")
println(E_B_max)
println("------------ Generator Capacity [MW] -------------------")
println(C_G)
