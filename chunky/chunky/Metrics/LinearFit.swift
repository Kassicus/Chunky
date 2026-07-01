// chunky/chunky/Metrics/LinearFit.swift

/// Ordinary least-squares fit of y vs x (plain Swift, no Accelerate).
nonisolated enum LinearFit {
    struct Result: Equatable {
        let slope: Double
        let intercept: Double
        let rmsResidual: Double
    }

    static func fit(x: [Double], y: [Double]) -> Result? {
        guard x.count == y.count, x.count >= 2 else { return nil }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var sxx = 0.0
        var sxy = 0.0
        for i in 0..<x.count {
            let dx = x[i] - meanX
            sxx += dx * dx
            sxy += dx * (y[i] - meanY)
        }
        guard sxx > 0 else { return nil }
        let slope = sxy / sxx
        let intercept = meanY - slope * meanX
        var sumSqResid = 0.0
        for i in 0..<x.count {
            let resid = y[i] - (slope * x[i] + intercept)
            sumSqResid += resid * resid
        }
        let rms = (sumSqResid / n).squareRoot()
        return Result(slope: slope, intercept: intercept, rmsResidual: rms)
    }
}
