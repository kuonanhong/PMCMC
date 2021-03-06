##################################################################
# State space model - linear gaussian
##################################################################


##################################################################
# Model specification
##################################################################

# SSM params
phi = 0.95
mu = 0.9
sigma_2 = 0.01
sigma = sqrt(sigma_2)
eta_2 = (sigma_2/(1-phi^2))/5
eta = sqrt(eta_2)
prior_par = c(0,1) # mean and sd of the prior distribution for x1


source("propagate_SSM.R")

# Problem specific functions 

linear_state_update = function(x_k, k, theta_state){
  mu = theta_state[1] 
  phi = theta_state[2] 
  sigma = theta_state[3] 
  error_value = rnorm(1, mean=0, sd=1)
  x_k1 = mu + phi*(x_k-mu) + sigma*error_value
  return (x_k1)  
}

linear_obs_update = function (x_k, theta_obs){
  eta = theta_obs[1]  
  error_value = rnorm(1, mean=0, sd=1)
  y_k = x_k + eta*error_value
  return (y_k)
}

calculate_weight_linear = function(observed_val, particles_vals, theta_obs){
  # This weight calculation is SSM dependant
  weight  = dnorm(observed_val, mean = particles_vals, sd=theta_obs[1]) # weights here are from prob density g evaulated at y1|x_1 for all steps
}

calculate_weight_linear_LOG = function(observed_val, particles_vals, theta_obs){
  # This weight calculation is SSM dependant
  weight  = (-(observed_val-particles_vals)^2)/(2*theta_obs[1])-log(sqrt(2*(theta_obs[1]^2)*pi)) # weights here are from prob density g evaulated at y1|x_1 for all steps
}



##################################################################
# Data generation
##################################################################

t = 100 # num of iters in time

data=generate_data(linear_state_update,linear_obs_update, prior_par, t, plot=TRUE, theta_state = c(mu, phi, sigma), theta_obs = c(eta))
latent_process_linear = data$latent_process
observed_process_linear = data$observed_process
data$plot

##################################################################
# Use SMC/particle filter to sample from underlying process X
##################################################################
source("SMC.R")

N = 100  #number of particles 

#run the SMC for the state space model
smc_output = SMC(N=N, calculate_weight=calculate_weight_linear, state_update=linear_state_update, observed_process=observed_process_linear, theta_state= c(mu, phi, sigma), theta_obs= c(eta))

# save result for the representation of the Kalman filter
particles_in_time = smc_output$particles_in_time
particle_mean_in_time = smc_output$particle_mean_in_time

# plot for the particles trajectories over the state space, along with the actual latent process used to generate the data we train on
plot_particles_and_latent_process(particles_in_time, latent_process_linear)


##################################################################
# Kalman filter for predictive distribution
##################################################################
library(FKF)

# give a state space representation of the linear gaussian model
linear_model_state_space = function(phi, mu, sigma, y_values, x_values) {
  Tt = matrix(phi)
  Zt = matrix(1)
  dt = as.matrix(mu-phi*mu)
  ct = as.matrix(0)
  HHt = matrix(sigma)
  GGt = matrix(mu)
  yt = as.matrix(y_values)
  a0 <- x_values[1]
  P0 <- matrix(1)
  return(list(a0 = a0, P0 = P0, ct = ct, dt = dt, Zt = Zt, Tt = Tt, GGt = GGt, HHt=HHt, yt=rbind(y_values)))
}

# Compute the Kalman filter       
sp = linear_model_state_space(phi=phi, mu=mu, sigma=sigma ,y_values=observed_process_linear[1:10], x_values=latent_process_linear[1:10])
ans = fkf(a0 = sp$a0, P0 = sp$P0, dt = sp$dt, ct = sp$ct, Tt = sp$Tt,
           Zt = sp$Zt, HHt = sp$HHt, GGt = sp$GGt, yt = sp$yt)


# Store the values for the plot the predictive distributions
predicted_exp_value = t(cbind(ans$at[1], ans$att))
predicted_var = as.matrix(c(ans$Pt[1], as.vector(ans$Ptt)))
x = seq(-8,8, by=0.01)
values_to_plot = matrix(NA, nrow = length(x),ncol=length(predicted_exp_value))
for (i in 1:(10+1)){
  values_to_plot[,i] = dnorm(x, mean=predicted_exp_value[i,],sd=sqrt(predicted_var[i,]))
}
data_frame = as.data.frame(values_to_plot)
data_frame$x_values = x
data_frame_melt = melt(data_frame, id=c("x_values"))
n_values=as.matrix(table(data_frame_melt$variable))

particle_means_df = data.frame(means = particle_mean_in_time[1:11])
particle_means_df$variable = colnames(data_frame)[1:11]

data_frame_melt$variable = factor(data_frame_melt$variable, levels=c('V1','V2','V3','V4','V5','V6','V7','V8','V9','V10','V11','V12','V13','V14','V15','V16','V17','V18','V19','V20','V21'))
particle_means_df$variable = factor(particle_means_df$variable, levels = c('V1','V2','V3','V4','V5','V6','V7','V8','V9','V10','V11','V12','V13','V14','V15','V16','V17','V18','V19','V20','V21'))




# Plot the sequence of predictive distributions WITHOUT RED DOTS
plot1 = ggplot() +  
  geom_point(data=data_frame_melt, aes(x=value, y = x_values, group = variable, colour = "black"), size=0.05, colour="#000099") + 
  labs(x="Time index",y="State values") + 
  xlim(0,1.5) +
  ylim(c(-4,4)) +
  theme(legend.position="none", plot.title = element_text(hjust = 0.5)) +
  facet_wrap(~variable, ncol = n_values[1] ) +
  theme(strip.background = element_blank(), 
        strip.text.x = element_blank(),
        axis.text.x=element_blank(), 
        axis.ticks.x=element_blank(), 
        axis.text=element_text(size=4), 
        axis.title=element_text(size=4), 
        plot.title = element_text(size=rel(1),lineheight=.6, face="bold"))
ggsave("plots/kalman_filter1.pdf", width = 4, height = 2)
plot1




# Plot the sequence of predictive distributions with RED DOTS
plot2 = ggplot() +  
  geom_point(data=data_frame_melt, aes(x=value, y = x_values, group = variable, colour = "black"), size=0.05, colour="#000099") + 
  geom_point(data = particle_means_df, aes(x=1, y = means, colour = "red", group = variable), size=3, alpha=0.6) +
  labs(x="Time index",y="State values") + 
  xlim(0,2) +
  ylim(c(-4,4)) +
  theme(legend.position="none", plot.title = element_text(hjust = 0.5)) +
  facet_wrap(~variable, ncol = n_values[1] ) +
  theme(strip.background = element_blank(), 
        strip.text.x = element_blank(),
        axis.text.x=element_blank(), 
        axis.ticks.x=element_blank(), 
        axis.text=element_text(size=4), 
        axis.title=element_text(size=4), 
        plot.title = element_text(size=rel(1),lineheight=.6, face="bold"))
ggsave("plots/kalman_filter2.pdf", width = 4, height = 2)
plot2



##################################################################
# PIMH for a linear gaussian model
##################################################################
source("PIMH.R")

n_iter = 50

PIMH_linear = PIMH(n_iter, 
                   N, 
                   calculate_weight=calculate_weight_linear,  
                   state_update=linear_state_update, 
                   observed_process=observed_process_linear,
                   theta_state = c(mu, phi,sigma),
                   theta_obs = c(eta))

# save data for PIMH linear
data_path = paste('plots/linear_PIMH_', format(Sys.time(), "%Y_%m_%d_%H_%M_%S"), '.rdata', sep='')
save(PIMH_linear, file = data_path)


plot_linear=trace_plot(PIMH_linear$state_values[1,], 
                n_iter, 
                title = "Markov Chain for the first particle")
plot_linear




##################################################################
# PMMH for a linear gaussian model
##################################################################
source("PMMH.R")

n_iter = 100
d = 1        #update only phi

mu = 0.9
sigma_2 = 0.01
sigma = sqrt(sigma_2)
eta_2 = 0.02
eta = sqrt(eta_2)
prior_par = c(0,1) # mean and sd of the prior distribution for x1

PMMH_linear = PMMH_linear(n_iter,
                    N,
                    d,
                    calculate_weight=calculate_weight_linear_LOG,
                    state_update=linear_state_update,
                    observed_process=observed_process_linear,
                    theta_state = c(mu, phi, sigma),
                    theta_obs = c(eta) )
 
# save data for PIMH linear
data_path = paste('plots/linear_PMMH_', format(Sys.time(), "%Y_%m_%d_%H_%M_%S"), '.rdata', sep='')
save(PMMH_linear, file = data_path)


# plot_PMMH_linear=trace_plot(PMMH_linear$state_values[1,], 
#                         n_iter, 
#                         title = "Markov Chain for the first particle")
# 
# plot_PMMH_par=trace_plot(PMMH_linear$theta_unknown[,1:(n_iter+1)], 
#                             n_iter, 
#                             title = "parameter space")
# 
# plot(seq(from=1, to=n_iter+1, by=1), 
#      PMMH_linear$theta_unknown[,1:(n_iter+1)], 
#      type="l",
#      xlab = "Iterations",
#      ylab = "Parameter values")


##################################################################
# Produce plot of SMC in time
##################################################################

source("SMC.R")

N = 100  #number of particles 
 

# t=8
observed_process_linear_t2=observed_process_linear[1:8]
smc_output = SMC(N=N, calculate_weight=calculate_weight_linear, state_update=linear_state_update, observed_process=observed_process_linear_t2, theta_state= c(mu, phi, sigma), theta_obs= c(eta))
particles_in_time = smc_output$particles_in_time
particle_mean_in_time = smc_output$particle_mean_in_time
# plot for the particles trajectories over the state space, along with the actual latent process used to generate the data we train on
plot_particles_and_latent_process_NOLEGEND(particles_in_time, latent_process_linear)
ggsave("plots/smc_linear_t8.pdf")


# t=20
observed_process_linear_t2=observed_process_linear[1:20]
smc_output = SMC(N=N, calculate_weight=calculate_weight_linear, state_update=linear_state_update, observed_process=observed_process_linear_t2, theta_state= c(mu, phi, sigma), theta_obs= c(eta))
particles_in_time = smc_output$particles_in_time
particle_mean_in_time = smc_output$particle_mean_in_time
# plot for the particles trajectories over the state space, along with the actual latent process used to generate the data we train on
plot_particles_and_latent_process_NOLEGEND(particles_in_time, latent_process_linear)
ggsave("plots/smc_linear_t20.pdf")

 
 
# t=40
observed_process_linear_t2=observed_process_linear[1:40]
smc_output = SMC(N=N, calculate_weight=calculate_weight_linear, state_update=linear_state_update, observed_process=observed_process_linear_t2, theta_state= c(mu, phi, sigma), theta_obs= c(eta))
particles_in_time = smc_output$particles_in_time
particle_mean_in_time = smc_output$particle_mean_in_time
# plot for the particles trajectories over the state space, along with the actual latent process used to generate the data we train on
plot_particles_and_latent_process_NOLEGEND(particles_in_time, latent_process_linear)
ggsave("plots/smc_linear_t40.pdf")




# t=80
observed_process_linear_t2=observed_process_linear[1:80]
smc_output = SMC(N=N, calculate_weight=calculate_weight_linear, state_update=linear_state_update, observed_process=observed_process_linear_t2, theta_state= c(mu, phi, sigma), theta_obs= c(eta))
particles_in_time = smc_output$particles_in_time
particle_mean_in_time = smc_output$particle_mean_in_time
# plot for the particles trajectories over the state space, along with the actual latent process used to generate the data we train on
plot_particles_and_latent_process_NOLEGEND(particles_in_time, latent_process_linear)
ggsave("plots/smc_linear_t80.pdf")
