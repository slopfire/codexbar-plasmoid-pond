export function diameter(settings = {}) {
  const fallback = settings.ringLayout === "nested" ? 40 : 28;
  return Math.max(24, Math.min(44, Number(settings.ringSize) || fallback));
}

// Scale the requested widths and gaps together to keep every ring outside the center.
export function nestedRings(count, size, width, gap, style, centerSize) {
  const length = Math.max(0, Math.min(6, Math.floor(Number(count) || 0)));
  const widths = Array.from({length}, (_, i) => width * (style === "decreasing" ? Math.pow(0.78, i) : 1));
  const needed = widths.reduce((sum, value) => sum + value, 0) + Math.max(0, length - 1) * gap;
  const available = Math.max(0, (size - 2 - centerSize) / 2);
  const scale = needed > 0 ? Math.min(1, available / needed) : 1;
  let outer = size - 2;
  return widths.map(value => {
    const stroke = value * scale;
    const ring = {size: outer, stroke};
    outer -= 2 * (stroke + gap * scale);
    return ring;
  });
}
