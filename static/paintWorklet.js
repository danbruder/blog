class CirclesPainter {
  paint(ctx, geom) {
    const colors = ['#2e1065', '#022c22', '#1f2937', '#44403c']; // Subtle color palette
    const shapes = ['circle', 'rectangle', 'line'];
    const maxShapes = geom.height / 3;

    for (let i = 0; i < maxShapes; i++) {
      const color = colors[Math.floor(Math.random() * colors.length)];
      const shape = shapes[Math.floor(Math.random() * shapes.length)];
      const x = Math.random() * geom.width;
      const y = Math.random() * geom.height;
      const size = Math.random() * 15 + 1; 
      const rotation = Math.random() * 180 + 1; 
      var direction = Math.random() < 0.5 ? -1 : 1;

      ctx.fillStyle = color;
      ctx.beginPath();

      if (shape === 'circle') {
        ctx.arc(x, y, size / 2, 0, 2 * Math.PI);
      } else if (shape == 'rectangle') { // rectangle
        ctx.rotate((rotation * direction * Math.PI) / 180);
        ctx.rect(x, y, size, size);
        ctx.setTransform(1, 0, 0, 1, 0, 0);
      } else if (shape == 'line') { // rectangle
        ctx.rotate((rotation * direction * Math.PI) / 180);
        ctx.rect(x, y, size / 3, size * 2);
        ctx.setTransform(1, 0, 0, 1, 0, 0);
      }

      ctx.fill();
    }
  }
}

registerPaint('circles', CirclesPainter);
