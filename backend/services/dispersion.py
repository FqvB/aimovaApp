import math

_EPS = 1e-9


def compute_dispersion(carries: list[float], offlines: list[float]) -> dict | None:
    """
    Compute 50% and 90% confidence ellipse parameters from carry/offline shot data.

    Returns None if fewer than 4 shots are provided.
    Handles degenerate cases (zero variance) by adding a small epsilon.
    """
    n = len(carries)
    if n < 4:
        return None

    mean_carry = sum(carries) / n
    mean_offline = sum(offlines) / n

    var_carry = max(
        sum((c - mean_carry) ** 2 for c in carries) / (n - 1),
        _EPS,
    )
    var_offline = max(
        sum((o - mean_offline) ** 2 for o in offlines) / (n - 1),
        _EPS,
    )
    cov = sum(
        (c - mean_carry) * (o - mean_offline) for c, o in zip(carries, offlines)
    ) / (n - 1)

    a = var_carry
    b = cov
    d = var_offline

    discriminant = math.sqrt(max(0.0, (a - d) ** 2 + 4 * b * b))
    lambda1 = (a + d + discriminant) / 2
    lambda2 = max((a + d - discriminant) / 2, _EPS)

    if abs(b) > _EPS:
        vx, vy = b, lambda1 - a
    elif a >= d:
        vx, vy = 1.0, 0.0
    else:
        vx, vy = 0.0, 1.0

    rotation_degrees = math.degrees(math.atan2(vy, vx))

    def _ellipse(confidence: float) -> dict:
        s = math.sqrt(-2.0 * math.log(1.0 - confidence))
        return {
            "semi_major": s * math.sqrt(lambda1),
            "semi_minor": s * math.sqrt(lambda2),
            "rotation_degrees": rotation_degrees,
        }

    return {
        "mean_carry": mean_carry,
        "mean_offline": mean_offline,
        "covariance_matrix": [[a, b], [b, d]],
        "ellipse_50": _ellipse(0.5),
        "ellipse_90": _ellipse(0.9),
    }
