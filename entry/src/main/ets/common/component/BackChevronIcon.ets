@Component
export struct BackChevronIcon {
  build() {
    Polyline({ width: 18, height: 18 })
      .points([[14, 3.8], [5, 9], [14, 14.2]])
      .fill(Color.Transparent)
      .stroke('#1F2937')
      .strokeWidth(2.4)
      .strokeLineCap(LineCapStyle.Round)
      .strokeLineJoin(LineJoinStyle.Round);
  }
}
