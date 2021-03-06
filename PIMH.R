source("plotting_functions.R")
source("SMC.R")

PIMH = function(n_iter, 
                N, 
                calculate_weight, 
                state_update, 
                observed_process,
                theta_state, 
                theta_obs){
  t=length(observed_process)                            #number of observed step in times

  n_acceptance=0
  state_values = matrix(NA, nrow = t, ncol = n_iter+1 ) #store the state values at each step
  lik_values = vector(length = n_iter+1 )               #store the lik value at each step
  
  # run an SMC for iteration 0
  smc_output = SMC(N = N, 
                    calculate_weight = calculate_weight, 
                    state_update = state_update, 
                    observed_process = observed_process,
                    theta_state, 
                    theta_obs)
  
  index = sample(1:N, 1, prob = smc_output$weights_in_time[t, ]) #to check
  proposed_x = smc_output$particles_in_time[,index]
  proposed_lik = smc_output$lik_in_time[t]
  
  # store the first two values
  lik_values[1]=proposed_lik
  state_values[,1]=proposed_x
  #cat("first prop lik", proposed_lik, '\n')
  
  for (i in 1:n_iter){
    # run an SMC for each iteration from 1 to n_iter
    smc_output = SMC(N=N, 
                      calculate_weight=calculate_weight, 
                      state_update=state_update, 
                      observed_process=observed_process,
                      theta_state,
                      theta_obs)
    
    # sample the path x1:xT to consider
    index = sample(1:N, 1, prob = smc_output$weights_in_time[t, ])
    proposed_x = smc_output$particles_in_time[,index]
    proposed_lik = smc_output$lik_in_time[t]
    
    #cat("prop_lik",exp(proposed_lik),'\n')
    #cat("lik_val", exp(lik_values[i]),'\n')
    #cat("ratio", exp(proposed_lik)/exp(lik_values[i]),'\n')
    # compute the accepatance probability
    
    thing = exp(proposed_lik - lik_values[i])
    acc_prob = min(c(1, thing) )
    
    #cat(acc_prob)
    # accept or reject the new value
    #if (log(runif(1)) < acc_prob) { 
    if(runif(1) < acc_prob){
      state_values[, i+1] = proposed_x
      lik_values[i+1] = proposed_lik
      n_acceptance = n_acceptance + 1
    } else {
      state_values[, i+1] = state_values[,i] 
      lik_values[i+1] = lik_values[i]
    }
    
    # compute the ratio of accepted values
    acceptance_ratio = n_acceptance/n_iter
  }
  
  out=list(state_values = state_values,
           lik_values = lik_values,
           acceptance_ratio = acceptance_ratio
           )
  
  return(out)
}

