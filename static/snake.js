document.addEventListener(
  "DOMContentLoaded",
  function () {
    const { fromEvent, interval } = rxjs;
    const {
      map,
      filter,
      startWith,
      scan,
      distinctUntilChanged,
      share,
    } = rxjs;
    const canvas = document.getElementById('gameCanvas');
    const ctx = canvas.getContext('2d');
    const SCALE = 20; // Size of each square
    const WIDTH = canvas.width / SCALE;
    const HEIGHT = canvas.height / SCALE;

    // Game settings
    const DIRECTIONS = {
      LEFT: { x: -1, y: 0 },
      RIGHT: { x: 1, y: 0 },
      UP: { x: 0, y: -1 },
      DOWN: { x: 0, y: 1 },
    };

    const TICK_RATE = 150;
    const INITIAL_DIRECTION = DIRECTIONS.RIGHT;
    const INITIAL_LENGTH = 5;

    // Utility functions
    const willEat = (head, food) => head.x === food.x && head.y === food.y;
    const willCrash = (head, body) => {
      const withSelf = body.some((segment) => segment.x === head.x && segment.y === head.y);
      const withWall = head.x < 0 || head.x >= WIDTH || head.y < 0 || head.y >= HEIGHT;
      return withSelf || withWall;
    }
    const getRandomFoodPosition = () => ({
      x: Math.floor(Math.random() * 20),
      y: Math.floor(Math.random() * 20),
    });

    // Game observables
    const tick$ = interval(TICK_RATE);
    const keyDown$ = fromEvent(document, "keydown");

    // Snake direction observable
    const direction$ = keyDown$.pipe(
      map((event) => {
        switch (event.code) {
          case "ArrowUp":
            return DIRECTIONS.UP;
          case "ArrowDown":
            return DIRECTIONS.DOWN;
          case "ArrowLeft":
            return DIRECTIONS.LEFT;
          case "ArrowRight":
            return DIRECTIONS.RIGHT;
          default:
            return;
        }
      }),
      filter((direction) => !!direction),
      distinctUntilChanged(),
      startWith(INITIAL_DIRECTION)
    );

    // Game state observable
    const gameState$ = tick$.pipe(
      rxjs.withLatestFrom(direction$),
      scan(
        ({ snake, food }, [_, direction]) => {
          let nextHead = {
            x: snake[0].x + direction.x,
            y: snake[0].y + direction.y,
          };

          if (willEat(nextHead, food)) {
            food = getRandomFoodPosition();
          } else {
            snake.pop();
          }

          if (willCrash(nextHead, snake)) {
            snake = [{ x: 10, y: 10 }];
            food = getRandomFoodPosition();
          } else {
            snake.unshift(nextHead);
          }

          return { snake, food };
        },
        {
          snake: Array.from({ length: INITIAL_LENGTH }, (_, i) => ({
            x: 10 + i,
            y: 10,
          })),
          food: getRandomFoodPosition(),
        }
      ),
      share()
    );

    // Function to draw a block (used for both snake and food)
    const drawBlock = (x, y, color) => {
      ctx.fillStyle = color;
      ctx.fillRect(x * SCALE, y * SCALE, SCALE, SCALE);
    };

    // Subscribing to the game state to update the UI
    gameState$.subscribe(({ snake, food }) => {
      ctx.clearRect(0, 0, canvas.width, canvas.height); // Clear the canvas

      // Draw the food
      drawBlock(food.x, food.y, '#dc2626');

      // Draw the snake
      snake.forEach(segment => drawBlock(segment.x, segment.y, '#84cc16'));
    });
  },
  false
);
