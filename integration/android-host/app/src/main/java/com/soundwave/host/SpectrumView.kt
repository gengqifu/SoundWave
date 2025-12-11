package com.soundwave.host

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import kotlin.math.log10

class SpectrumView @JvmOverloads constructor(
  context: Context,
  attrs: AttributeSet? = null
) : View(context, attrs) {

  private var spectrum: FloatArray = floatArrayOf()
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    color = 0xFF2196F3.toInt()
    strokeWidth = 3f
  }

  fun setSpectrum(values: FloatArray) {
    spectrum = values
    postInvalidateOnAnimation()
  }

  fun reset() {
    spectrum = floatArrayOf()
    postInvalidateOnAnimation()
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    if (spectrum.isEmpty()) return
    val h = height.toFloat()
    val w = width.toFloat()
    val barCount = spectrum.size.coerceAtMost(128) // 简化绘制
    val step = w / barCount
    for (i in 0 until barCount) {
      val v = spectrum[i].coerceAtLeast(1e-6f)
      // 对数压缩便于显示
      val db = (20 * log10(v.toDouble())).toFloat()
      val norm = ((db + 60f) / 60f).coerceIn(0f, 1f)
      val barHeight = norm * h
      val x = i * step
      canvas.drawLine(x, h, x, h - barHeight, paint)
    }
  }
}
