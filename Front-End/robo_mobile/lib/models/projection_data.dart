/// Data classes for Monte Carlo future projection.
class ProjectionParams {
  final double mu;
  final double sigma;
  final double currentValue;
  final double currentAge;
  final double targetAge;
  final double monthlyContrib;
  final double oneTimeDeposit;
  final double feeRate;
  final int numSimulations;

  const ProjectionParams({
    required this.mu,
    required this.sigma,
    required this.currentValue,
    required this.currentAge,
    this.targetAge = 65,
    this.monthlyContrib = 0,
    this.oneTimeDeposit = 0,
    this.feeRate = 0.005,
    this.numSimulations = 1000,
  });
}

class ProjectionResult {
  final List<double> ages;
  final List<double> p10;
  final List<double> p25;
  final List<double> median;
  final List<double> p75;
  final List<double> p90;

  const ProjectionResult({
    required this.ages,
    required this.p10,
    required this.p25,
    required this.median,
    required this.p75,
    required this.p90,
  });

  int get length => ages.length;

  bool get isEmpty => ages.isEmpty;

  double get medianFinal => median.isEmpty ? 0 : median.last;
}
