using JuMP, Gurobi, Plots, Statistics

include("data.jl")
global pv_irra = pv_irra
global consumption = consumption

function lom(n_years, method)
	# optim model in Gurobi
	model = Model(Gurobi.Optimizer)
	set_optimizer_attribute(model, "Method", method)

	pv_irr = repeat(pv_irra, n_years*365)
	P_C = repeat(consumption, n_years*365)
	# constants
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
	@variable(model, E_B[time] >= 0)
	@variable(model, P_B_charge[time] >= 0)
	@variable(model, P_B_discharge[time] >= 0)

	# objective
	@objective(model, Min, pi_PV*C_PV + pi_B*E_B_max + pi_G*C_G + pi_D*sum(P_D))

	# constraints 
	@constraint(model, [t in time], P_PV[t] + n_G*P_D[t] + P_B_discharge[t] == P_B_charge[t] + P_C[t])
	@constraint(model, [t in time], n_G*P_D[t] <= C_G)
	@constraint(model, [t in time], P_PV[t] <= n_PV*pv_irr[t]*C_PV )
	@constraint(model, [t in 2:n_years*365*24], E_B[t] == n_B*E_B[t-1] + n_B_plus*P_B_charge[t-1] - P_B_discharge[t-1]/n_B_moins)
	@constraint(model, E_B[1] == mean(E_B[range(25,length(time),step=24)]))
	@constraint(model, E_B[end] == mean(E_B[range(24,length(time),step=24)]))
	@constraint(model, [t in time], E_B[t] <= E_B_max)

	optimize!(model)
	return MOI.get(JuMP.backend(model).optimizer, Gurobi.ModelAttribute("Runtime")) # also solve_time(model)

end

#Method 0 = primal simplex
#Method 2 = barrier
time = 1:5
simplex_time = Array{Float64}(undef, length(time))
barrier_time = Array{Float64}(undef, length(time))
N = 5
for n_years in time
	temp_exec_simplex = Array{Float64}(undef, N)
	temp_exec_barrier = Array{Float64}(undef, N)
	for i in 1:N
		temp_exec_simplex[i] = lom(n_years, 0)
		temp_exec_barrier[i] = lom(n_years, 2)
	end
	simplex_time[n_years] = mean(temp_exec_simplex)
	barrier_time[n_years] = mean(temp_exec_barrier)
end

time_exec = [simplex_time barrier_time]
labels = ["Simplex method" "Barrier method"]
plot(time, time_exec, labels=labels, legend=:topleft)
xlabel!("Number of years")
ylabel!("Execution time [s]")	
title!("Optimization time for simplex and barrier methods")
savefig("exec_time.pdf")