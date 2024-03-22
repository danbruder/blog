document.addEventListener('DOMContentLoaded', function(){ 
  if ("paintWorklet" in CSS) {
    CSS.paintWorklet.addModule("/paintWorklet.js");
  } else { 
    let canvas = document.createElement('canvas');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    let ctx = canvas.getContext('2d');
    let cp = new CirclesPainter;
    cp.paint(ctx, {width: canvas.width, height: canvas.height});
    let url = canvas.toDataURL();
    let el = document.body;
    el.style.backgroundImage = `url(${url})`;
  }
}, false);
