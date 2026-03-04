# R Packages for Epidemiology

Guide to key R packages used in epidemiological research and infectious disease modeling.

## EpiModel
**Purpose**: Mathematical Modeling of Infectious Disease Dynamics
- **Models**: Deterministic compartmental models (DCM), stochastic individual-contact models (ICM), stochastic network models (Network)
- **Disease Types**: SI, SIR, SIS
- **Key Features**: Network modeling with ERGMs (Statnet integration)
- **Example Usage**:
  ```r
  library(EpiModel)
  param <- param.dcm(inf.prob = 0.2, act.rate = 1, rec.rate = 1/20)
  init <- init.dcm(s.num = 1000, i.num = 1, r.num = 0)
  control <- control.dcm(type = "SIR", nsteps = 500)
  mod <- dcm(param, init, control)
  plot(mod)
  ```

## epidemia
**Purpose**: Flexible Epidemic Modeling with Bayesian Inference
- **Approach**: Semi-mechanistic Bayesian models
- **Backend**: Precompiled Stan programs
- **Key Features**: Time-varying reproduction numbers, latent infections, multilevel models
- **Example Usage**:
  ```r
  library(epidemia)
  # Define model components (transmission, observations, latent infections)
  args <- EuropeCovid$args
  fit <- do.call(epim, args)
  plot_rt(fit)
  ```

## EpiNow2
**Purpose**: Estimate Real-Time Case Counts and Time-Varying Parameters
- **Approach**: Renewal equation with Bayesian inference (Stan)
- **Key Features**: Rt estimation, forecasting, delay distributions (incubation, reporting)
- **Example Usage**:
  ```r
  library(EpiNow2)
  # Estimate Rt from case data
  estimates <- epinow(reported_cases = cases)
  plot(estimates)
  ```

## EpiEstim
**Purpose**: Estimate Time-Varying Reproduction Numbers from Epidemic Curves
- **Approach**: Cori et al. (2013) method
- **Key Features**: Simple, fast Rt estimation from incidence time series
- **Example Usage**:
  ```r
  library(EpiEstim)
  res_parametric_si <- estimate_R(Incid, method="parametric_si",
                                  config = make_config(list(mean_si = 2.6, std_si = 1.5)))
  plot(res_parametric_si, legend = FALSE)
  ```

## epiparameter
**Purpose**: Library of Epidemiological Parameters
- **Features**: Database of parameters (R0, incubation periods) from literature
- **Usage**: Retrieve distributions for use in models
- **Example Usage**:
  ```r
  library(epiparameter)
  # Get incubation period for COVID-19
  covid_incubation <- epidist_db(disease = "COVID-19", epi_dist = "incubation")
  ```

## Other Essential Packages
- **survival**: Core survival analysis (Surv, coxph)
- **survminer**: Visualization for survival models (ggsurvplot)
- **epitools**: Epidemiology tools (odds ratio, risk ratio, confidence intervals)
- **Epi**: Analysis of follow-up data (Lexis diagrams)
