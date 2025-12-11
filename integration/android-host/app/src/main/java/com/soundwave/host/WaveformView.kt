package com.soundwave.host

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import kotlin.math.abs

class WaveformView @JvmOverloads constructor(
  context: Context,
  attrs: AttributeSet? = null
) : View(context, attrs) {

  private val samples = ArrayList<Float>()
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    color = 0xFF4CAF50.toInt()
    strokeWidth = 2f
  }
  private val maxPoints = 1024

  fun appendSamples(newSamples: FloatArray) {
    samples.addAll(newSamples.toList())
    // 限制缓存长度，保持最近一段波形
    if (samples.size > maxPoints) {
      val remove = samples.size - maxPoints
      repeat(remove) { samples.removeAt(0) }
    }
    postInvalidateOnAnimation()
  }

  fun reset() {
    samples.clear()
    postInvalidateOnAnimation()
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    if (samples.isEmpty()) return
    val h = height.toFloat()
    val w = width.toFloat()
    val mid = h / 2f
    val step = w / (samples.size.coerceAtLeast(1))
    var x = 0f
    for (value in samples) {
      val amp = (value.coerceIn(-1f, 1f)) * (mid * 0.9f)
      canvas.drawLine(x, mid - amp, x, mid + amp, paint)
      x += step
    }
  }
}
