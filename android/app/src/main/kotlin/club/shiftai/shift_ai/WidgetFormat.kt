package club.shiftai.shift_ai

import java.util.Locale

/** Shared by every widget provider — kept in one place so the three widgets read the same numbers the same way. */
fun formatMoney(value: Double): String = String.format(Locale.US, "%,.2f", value)

fun movementLabel(movement: Int): String = when {
    movement > 0 -> "▲ $movement UP"
    movement < 0 -> "▼ ${-movement} DOWN"
    else -> ""
}
