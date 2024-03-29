library(MCMCpack)


calcWeight <- function(u, alpha) {
  # Calculates weight for given u and alpha.
  # 
  # Args:
  #   u: A vector.
  #   alpha: A scalar.
  #   
  # Returns:
  #   The weight value. A scalar.
  gammaInv = rep(0, length(u))
  diffGammaInv = rep(0, length(u))
  for(i in 1:length(u)) {
    gammaInv[i] = invGammaCumulative(u[i], alpha)
    diffGammaInv[i] = diffAlphaInvGammaCumulative(u[i], alpha)
  }
  pi = getPiValue()
  weight = pi/((1/length(gammaInv))*(sum(diffGammaInv/gammaInv)) - sum(diffGammaInv)/sum(gammaInv))
  return(weight)
}

getPiValue <- function() {
  # get value of pi function to be used in calculation of weights.
  # 
  # Returns:
  #   A scalar value.
  if (piValue == "constant") {
    return(1)
  } else if (piValue == "jeffrey") {
    # Return jeffrey prior
    return(sqrt((1/(estAlpha[sampleIndex]^2)) + (1/(2-(exp(estAlpha[sampleIndex]) + exp(-estAlpha[sampleIndex]))))))
  } else if (piValue == "betaOption") {
    return(estBeta)
  } else if (piValue == "alphaOption") {
    return(estAlpha[sampleIndex])
  }
}

calcPhi <- function(u, alpha) {
  xValue = rep(0, length(u))
  for(i in 1:length(u)) {
    xValue[i] = invGammaCumulative(u[i], alpha)
  }
  return(calcPhiGivenX(xValue))
}

calcPhiGivenX <- function(x) {
  # Calc phi value for a vector x.
  # 
  # Args:
  #   x: A vector of data.
  #   
  # Returns:
  #  A scalar.
  
  if(phiOption == "probValueOption") {
    phiPoint = rep(0, length(x))
    for(i in 1:length(x)) {
      phiPoint[i] = getPhiValue(x[i])
    }
    return(sum(phiPoint)/length(phiPoint))  
  } else if(phiOption == "x1x2divX3Option") {
    return(getPhiValue(x[1]*x[2]/x[3]))
  } else if(phiOption == "x1divx2powx3Option") {
    return(getPhiValue((x[1]/x[2])^x[3]))
  }
  return(-1)
}


getPhiValue <- function(xValue) {
  # Calculates phi for an element of an x vector.
  # 
  # Args:
  #   xValue: A scalar value.
  #   
  # Returns:
  #   
  return(xValue > probValue)
}

invGammaCumulative <- function(u, alpha) {
  # Finds the inverse of the cumulative gamma.
  # 
  # Args:
  #   u: Scalar value.
  #   alpha: Scalar value.
  #   
  # Returns:
  #   A scalar. The inverse value given u and alpha.
  x = 0
  stepSize = 0.1
  tolerance = 0.00001
  direction = 1
  integralValue = 0
  
  while(abs(integralValue - u) > tolerance){
    x = x + direction*stepSize
    if(x<0) {
      x = 0
      direction = 1
    }
    
    if(method == "integrate") {
      integralv = integrate(gammaDensity, 0, x)
      integralValue = integral$valuev
    } else if(method == "pgamma") {
      integralv = pgamma(x, shape=alpha, scale=1)
      integralValue = integralv
    }
    
    
    # Going left and pass the point
    if ((u > integralValue) && (direction == -1)) {
      stepSize = stepSize/2
      direction = 1
    }
    
    # Going right and pass the point
    if ((u < integralValue) && (direction == 1)) {
      stepSize = stepSize/2
      direction = -1
    }
  }
  return(x)
}

diffAlphaInvGammaCumulative <- function(u, alpha) {
  # Derivative of gamma distribution with respect to alpha.
  # 
  # Args:
  #   u: Scalar between 0 and 1.
  #   alpha: Scalar larger than 0.
  #   
  # Returns:
  #   Scalar value. Derivative at point alpha.
  firstPoint = invGammaCumulative(u,alpha)
  secondPoint = invGammaCumulative(u, alpha + alphaHStep)
  return((secondPoint - firstPoint)/alphaHStep)
}

calcDerivateFunction <- function(u, alphaValue) {
  # Analytically find the derivative of cumulative inverse.
  # 
  # Args:
  #   u: Scalar value between 0 and 1.
  #   alphaValue: Scalar value.
  #   
  # Returns:
  #   A scalar value.
  largeFInv = invGammaCumulative(u, alphaValue)
  integralPart = integrate(integralFunction, 0, largeFInv)
  return((digamma(alphaValue)*u - integralPart$value)*gamma(alphaValue)/((largeFInv^(alphaValue - 1))*exp(-largeFInv)))
}

integralFunction <- function(y) {
  # Function to be integrated.
  return(log(y)*(y^(alphaValue - 1))*exp(-y)/gamma(alphaValue))
}

optimfindAlpha <- function(u, s2) {
  if((calcValueTau2(u, alphaUpperBound) < s2) || (calcValueTau2(u, alphaLowerBound) > s2)) {
    return(-1)
  }
  solution = optim(c(0.1), optimFunction, u=u, lower=alphaLowerBound, upper=alphaUpperBound, method="Brent")
  return(solution$par)
}

optimFunction <- function(alpha, u) {
  return(abs(s2-calcValueTau2(u, alpha)))
}

findBeta <- function(s1, u, alphaValue) {
  # Calculates beta
  # 
  # Args:
  #   s1: Scalar value.
  #   u: Vector of values between 0 and 1.
  #   alphaValue: Scalar value.
  #   
  # Returns:
  #   A scalar value.
  largeFInv = rep(0, length(u))
  for(i in 1:length(u)) {
    largeFInv[i] = invGammaCumulative(u[i], alphaValue)
  }
  return(s1*length(u)/(sum(largeFInv)))
}

calcValueTau2 <- function(u, alphaValue) {
  largeFInv = rep(0, length(u))
  for(i in 1:length(u)) {
    largeFInv[i] = invGammaCumulative(u[i], alphaValue)
  }
  return(length(u)*((prod(largeFInv))^(1/length(u)))/sum(largeFInv))
}

calcValueTau2Method2 <- function(x) {
  return(length(x)*((prod(x))^(1/length(x)))/sum(x))
}

gibbsSampling <- function(xInit) {
  NUM_ITERATIONS = 5000
  xCurrent = xInit
  for(i in 1:NUM_ITERATIONS) {
    randomXpos = sample(length(xCurrent), size=3)
    sumX = xCurrent[randomXpos[1]] + xCurrent[randomXpos[2]] + xCurrent[randomXpos[3]]
    prodX = xCurrent[randomXpos[1]]*xCurrent[randomXpos[2]]*xCurrent[randomXpos[3]]
    x1 = runif(1)*sumX
    if(isValidX1Proposal(x1, sumX, prodX)) {
      roots = findRoots(x1, sumX, prodX)
      x2 = roots[1]
      x3 = roots[2]
      if(is.nan(x2) || is.nan(x3)){
        print((x1^3 - 2*sumX*x1^2 + (sumX^2)*x1 - 4*prodX))
      }
      xProposal = xCurrent
      xProposal[randomXpos[1]] = x1
      xProposal[randomXpos[2]] = x2
      xProposal[randomXpos[3]] = x3
      alphaMetHastings = findAlphaMetHastings(c(xCurrent[randomXpos[1]], xCurrent[randomXpos[2]], xCurrent[randomXpos[3]]), c(xProposal[randomXpos[1]], xProposal[randomXpos[2]], xProposal[randomXpos[3]]))
      acceptProb = runif(1)
      if(acceptProb <= alphaMetHastings) {
        xCurrent = xProposal
      }
    }
  }
  return(xCurrent)
}

isValidX1Proposal <- function(x1, sumX, prodX) {
  return((x1^3 - 2*sumX*x1^2 + (sumX^2)*x1 - 4*prodX) > 0)
}

findRoots <- function (x1, sumX, prodX) {
  root1 = ((sumX - x1) + sqrt( (sumX - x1)^2 - 4*prodX/x1 ))/2
  root2 = ((sumX - x1) - sqrt( (sumX - x1)^2 - 4*prodX/x1 ))/2
  return(c(root1, root2))
}

findAlphaMetHastings <- function(xCurrent, xProposal) {
  piProp = 1/(xProposal[1]*sqrt((sum(xProposal)  - xProposal[1])^2 - 4*prod(xProposal)/xProposal[1] ))
  piCurrent = 1/(xCurrent[1]*sqrt((sum(xCurrent)  - xCurrent[1])^2 - 4*prod(xCurrent)/xCurrent[1] ))
  return(min(1, piProp/piCurrent))
}


GammaGibbsSampling <- function(xInit) {
  # A Gibbs sampling for a Gamma distribution
  # 
  # Args:
  #   xInit: Initial sample. A vector.
  #   
  # Return:
  #   A sample from a Gamma distribution. A vector.
  NUM_ITERATIONS = 5000
  xCurrent = xInit
  for(i in 1:NUM_ITERATIONS) {
    randomXpos = sample(length(xCurrent), size=3)
    sumX = xCurrent[randomXpos[1]] + xCurrent[randomXpos[2]] + xCurrent[randomXpos[3]]
    prodX = xCurrent[randomXpos[1]]*xCurrent[randomXpos[2]]*xCurrent[randomXpos[3]]
    x1 = runif(1)*sumX
    if(isValidX1Proposal(x1, sumX, prodX)) {
      roots = findRoots(x1, sumX, prodX)
      x2 = roots[1]
      x3 = roots[2]
      if(is.nan(x2) || is.nan(x3)){
        print((x1^3 - 2*sumX*x1^2 + (sumX^2)*x1 - 4*prodX))
      }
      xProposal = xCurrent
      xProposal[randomXpos[1]] = x1
      xProposal[randomXpos[2]] = x2
      xProposal[randomXpos[3]] = x3
      alphaMetHastings = findGammaAlphaMetHastings(c(xCurrent[randomXpos[1]], xCurrent[randomXpos[2]], xCurrent[randomXpos[3]]), c(xProposal[randomXpos[1]], xProposal[randomXpos[2]], xProposal[randomXpos[3]]))
      acceptProb = runif(1)
      if(acceptProb <= alphaMetHastings) {
        xCurrent = xProposal
      }
    }
  }
  return(xCurrent)
  
}

findGammaAlphaMetHastings <- function(xCurrent, xProposal) {
  piProp = 1/(xProposal[1]*sqrt((sum(xProposal)  - xProposal[1])^2 - 4*prod(xProposal)/xProposal[1] ))
  piCurrent = 1/(xCurrent[1]*sqrt((sum(xCurrent)  - xCurrent[1])^2 - 4*prod(xCurrent)/xCurrent[1] ))
  if(is.nan(piCurrent)) {
    print(xCurrent)
  }
  return(min(1, piProp/piCurrent))
}


cramerVonMisesValueTest <- function(x, alpha, beta) {
  # Calculates the value for a Cramer-von Mises test.
  # 
  # Args:
  #   x: A vector sample.
  #   
  # Returns:
  #   A scalar value.
  cramerSum = 0
  for(i in 1:length(x)) {
    cramerSum = cramerSum + ((2*i - 1)/(2*length(x)) - pgamma(x[i], shape=alpha, scale=beta))^2
  }
  cramer = 12/(length(x)) + cramerSum
  return(cramer)
}

findGammaMLE <- function(x){
  solution = optim(c(1,1), negativeLogLikelihoodGamma, x=x)
  return(solution$par)
}

negativeLogLikelihoodGamma <- function(par, x) {
  # Calculates the negative log-likelihood for a gamma distribution.
  # 
  # Args:
  #   par: A vector of size 2. First element is alpha and second element is beta.
  #   x: Data to calculate log-likelihood from. A vector.
  #   
  # Returns:
  #  The log-likelihood value. A scalar
  alpha = par[1]
  beta = par[2]
  logLikelihood = -((alpha - 1)*sum(log(x)) - (1/beta)*sum(x) - length(x)*log(gamma(alpha)) - alpha*length(x)*log(beta))
  return(logLikelihood)
}

calcAveragPhiValueForData <- function(mydata) {
  sumData = sum(mydata)
  prodData = prod(mydata)
  tolerance = 0.03
  minValue = min(mydata) - 2*tolerance
  maxValue = max(mydata) + 2*tolerance
  sampleNumber = 1
  NUM_ITERATIONS = 10000
  sumPhi = 0
  while(sampleNumber <= NUM_ITERATIONS) {
    x = runif(3, max = sumData)
    if((abs(sum(x) - sumData) < tolerance) && (abs(prod(x) - prodData) < tolerance)) {
      sumPhi = sumPhi + calcPhiGivenX(x)
      sampleNumber = sampleNumber + 1  
      print(sampleNumber)
    }
  }
  return(sumPhi/(sampleNumber-1))
}

algorithm2Sampling <- function() {
  NUM_ALG2_SAMPLES = 100000
  vCurr = runif(NUM_POINTS)
  alphaCurr = optimfindAlpha(vCurr, s2)
  while(alphaCurr==-1) {
    vCurr = runif(NUM_POINTS)
    alphaCurr = optimfindAlpha(vCurr, s2)
  }
  piCurr = calcWeight(vCurr, alphaCurr)
  phiSum = 0
  
  for(i in 1:NUM_ALG2_SAMPLES) {
    print(i)
    vProp = runif(NUM_POINTS)
    alphaProp = optimfindAlpha(vProp, s2)
    piProp = 0
    if(alphaProp != -1) {
      piProp = calcWeight(vProp, alphaProp)
    }
    alphaMetHastings = min(1, piProp/piCurr)
    uProb = runif(1)
    if(uProb <= alphaMetHastings) {
      vCurr = vProp
      alphaCurr = alphaProp
      piCurr = piProp
    }
    betaCurr = findBeta(s1, vCurr, alphaCurr)
    xSample = rep(0, length(vCurr))
    for(i in 1:length(vCurr)) {
      xSample[i] = betaCurr*invGammaCumulative(vCurr[i], alphaCurr)
    }
    phiSum = phiSum + calcPhiGivenX(xSample)
  }
  return(phiSum/NUM_ALG2_SAMPLES)
}

algorithm1Sampling <- function() {
  NUM_ALG1_SAMPLES = 100000
  phiSum = 0
  for(i in 1:NUM_ALG1_SAMPLES) {
    print(i)
    u = runif(NUM_POINTS)
    alphavalue = optimfindAlpha(u, s2)
    while(alphavalue == -1) {
      u = runif(NUM_POINTS)
      alphavalue = optimfindAlpha(u, s2)
    }
    betavalue = findBeta(s1, u, alphavalue)
    xSample = rep(0, length(u))
    for(i in 1:length(u)) {
      xSample[i] = betavalue*invGammaCumulative(u[i], alphavalue)
    }
    phiSum = phiSum + calcPhiGivenX(xSample)
  }
  return(phiSum/NUM_ALG1_SAMPLES)
}

naiveSampling2 <- function(myData) {
  NUM_NAIVE_SAMPLES = 10000
  sumData = sum(myData)
  prodData = prod(myData)
  tolerance = 0.01
  sampleNumber = 0
  sumPhi = 0
  while(sampleNumber<NUM_NAIVE_SAMPLES) {
    x = rgamma(3,1,1)
    if((abs(sum(x) - sumData) < tolerance) && (abs(prod(x) - prodData) < tolerance)) {
      sumPhi = sumPhi + calcPhiGivenX(x)
      sampleNumber = sampleNumber + 1  
      print(sampleNumber)
    }
  }
  return(sumPhi/sampleNumber)
}

alpha = 1
beta = 1
hStep = 0.01
alphaHStep = 0.01
method = "pgamma"
NUM_SAMPLES = 1000
NUM_POINTS = 3
alphaUpperBound = 200
alphaLowerBound = 0.05
# Pi is used in calculation of weights
# Options are:
#   "constant"
#   "betaOption"
#   "jeffrey"
#   "alphaOption"
piValue = "constant"

phi = rep(0, NUM_SAMPLES)
# Phi options:
# x larger than a: "probValueOption"
# x1 times x2 div x3: "x1x2divX3Option"
# x1 div x2 pow x3: "x1divx2powx3Option"
phiOption = "probValueOption"
# Phi is the prob that X>probValue
probValue = 0.5

# Data generation options:
# pgamma generated: "pgamma"
# Bo data: "bo"
# Custom data: "custom"
# Custom data2: "custom2"
dataGenOption = "custom"



# Generate data
gammaData = 0
if(dataGenOption == "pgamma") {
  gammaData = rgamma(NUM_POINTS, shape=alpha, scale = beta)  
} else if(dataGenOption == "bo") {
  NUM_POINTS = 6
  alphaUpperBound = 1.2
  alphaLowerBound = 0.8
  gammaData = c(4.399, 1.307, 0.085, 0.7910, 0.2345, 0.1915)
} else if(dataGenOption == "custom") {
  gammaData = c(0.5772030, 0.4340237, 0.4212959)
} else if(dataGenOption == "custom2") {
  gammaData = c(1.621813, 1.059797, 1.554334)
}
hist(gammaData)
# Calculation of statistics
s1 = sum(gammaData)/NUM_POINTS
s2 = NUM_POINTS*((prod(gammaData))^(1/NUM_POINTS))/sum(gammaData)
# Log-likelihood
negativeloglikihood = negativeLogLikelihoodGamma(c(alpha, beta), gammaData)
mleEstimators = findGammaMLE(gammaData)
mleAlpha = mleEstimators[1]
mleBeta = mleEstimators[2]
maxLogLikelihood = - negativeLogLikelihoodGamma(c(mleAlpha, mleBeta), gammaData)
# w statistic obs. Not to be used yet.
wObs = calcPhiGivenX(gammaData)
cramerObs = cramerVonMisesValueTest(gammaData, mleAlpha, mleBeta)


# Calc Phi value for data
phiValue = calcAveragPhiValueForData(gammaData)
naivePhiValue = naiveSampling2(gammaData)

# Generation of samples. Not to be used

# weightsW = rep(0, NUM_SAMPLES)
# sampleIndex = 1
# iterationNumber = 0
# estAlpha = rep(0, NUM_SAMPLES)
# estBeta = 0
# while(sampleIndex <= NUM_SAMPLES) {
#   u = runif(NUM_POINTS)
#   estAlpha[sampleIndex] = optimfindAlpha(u, s2)
#   if(estAlpha[sampleIndex] != -1) {
#     estBeta = findBeta(s1, u, estAlpha[sampleIndex])
#     if(estBeta > alphaLowerBound && estBeta < alphaUpperBound) {
#         
#       weightsW[sampleIndex] = abs(calcWeight(u, estAlpha[sampleIndex]))
#       phi[sampleIndex] = calcPhi(u, estAlpha[sampleIndex])
#       
#       sampleIndex = sampleIndex + 1
#       print(sampleIndex)
#     }
#     
#   }
#   #print(iterationNumber)
#   iterationNumber = iterationNumber + 1
# }
# alphaAcceptance = (sampleIndex-1)/iterationNumber
# hist(weightsW, breaks = 400)
# expectedPhi = sum(phi*weightsW)/sum(weightsW)
# plot(estAlpha, weightsW)
# unweightedExpectedPhi = sum(phi)/NUM_SAMPLES

# Gibbs sampling
NUM_GIBBS_SAMPLES = 100000
xSample = gammaData
phiGibbs = rep(0, NUM_GIBBS_SAMPLES)
gibbsObslargerWObs = 0
cramerNum = 0
for(i in 1:NUM_GIBBS_SAMPLES) {
  xSample = gibbsSampling(xSample)
  phiGibbs[i] = calcPhiGivenX(xSample)
  if(phiGibbs[i] >= wObs) {
    gibbsObslargerWObs = gibbsObslargerWObs + 1
  }
  cramerStat = cramerVonMisesValueTest(xSample, mleAlpha, mleBeta)
  #print(cramerStat)
  if(cramerStat >= cramerObs) {
    cramerNum = cramerNum + 1
  }
  print(i)
}
gibbsS1 = sum(xSample)/NUM_POINTS
gibbsS2 = NUM_POINTS*((prod(xSample))^(1/NUM_POINTS))/sum(xSample)
gibbsPvalue = gibbsObslargerWObs/NUM_GIBBS_SAMPLES
averagePhiGibbs = sum(phiGibbs)/NUM_GIBBS_SAMPLES
# P-values
cramerPValue = cramerNum/NUM_GIBBS_SAMPLES

# Generate samples with algorithm 2.
alg2PhiValue = algorithm2Sampling()
alg1PhiVale = algorithm1Sampling()

# Save image
save.image(file="model13.RData")

print("Done")

