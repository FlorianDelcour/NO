using JuMP, Gurobi, Plots, Statistics

include("data.jl")
global pv_irra = pv_irra
global consumption = consumption

function lom(n_years, plt)

	# optim model in Gurobi
	model = Model(Gurobi.Optimizer)
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

	# Production and consumption during a typical week
	if plt == true
		index_week = 30
		week_time = 7*(index_week-1)*24 : 7*index_week*24
		P_PV = collect(value.(P_PV))[week_time]
		P_G = collect(value.(P_D)*n_G)[week_time]
		E_B = collect(value.(E_B))[week_time]
		P_C = P_C[week_time]
		P_B_charge = collect(value.(P_B_charge))[week_time]
		P_B_discharge = collect(value.(P_B_discharge))[week_time]

		data = [P_PV P_G P_C P_B_charge P_B_discharge]
		labels = ["PV_prod" "Genset_prod" "Consumption_load" "Charging_battery" "Discharging battery"]
		colors = [:blue2 :grey :red :green :orange]
		linestyle = [:solid :solid :solid :solid :dashdot]
		linewidth = [:auto 3 :auto :auto :auto]
		plot(week_time, data, labels=labels, size=(900, 600), left_margin = 5Plots.mm, color=colors, linewidth = linewidth, linestyle=linestyle)
		xlabel!("Time[hour]")
        ylabel!("Power prod/consum[MW]")
        title!(string("Power production and consumption of the microgrid elements, n_years = ", n_years))
        savefig(string("Q1_Prod_consum_", n_years, "_year.pdf"))

		plot(week_time, E_B, labels="", size=(900, 600), left_margin = 5Plots.mm)
		xlabel!("Time[hour]")
        ylabel!("Stored energy[MWh]")
        title!(string("State of charge of the battery, n_years = ", n_years))
        savefig(string("Q1_State_battery_", n_years, "_year.pdf"))
	end
end

lom(3, false)
#lom(5, false)