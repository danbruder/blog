if ('paintWorklet' in CSS) {
  console.log('Paint supported!')
  CSS.paintWorklet.addModule('/paintWorklet.js');
}
