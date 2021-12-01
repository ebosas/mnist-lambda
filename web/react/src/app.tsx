import React from "react";
import CanvasDraw from "react-canvas-draw";

function App() {
    const canvasDraw = React.useRef<CanvasDraw>() as React.MutableRefObject<CanvasDraw>;
    const canvasParent = React.useRef<HTMLDivElement>() as React.MutableRefObject<HTMLDivElement>;
    const [result, setResult] = React.useState<string>("Draw a digit above!");

    const checkDrawing = () => {
        let canvas = canvasParent.current.querySelectorAll<HTMLCanvasElement>('canvas')[1];
        let data: number[] = getPixelData(canvas);
        if (data.length != 28*28) {
            console.error("Input error");
            return
        }

        fetch('/api/mnist', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data),
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response');
            }
            return response.json();
        })        
        .then(data => {
            if (!('message' in data) || !data.message){
                throw new Error('Response message');
            }
            setResult(data.message);
        })
        .catch((error) => {
            console.error('Problem:', error);
        });
    }

    // Gets pixel data from the canvas resized to 28x28
    const getPixelData = (canvasMain: CanvasImageSource): number[] => {
        // Create a temp canvas, copy resized image
        let canvas = document.createElement('canvas');
        let ctx = canvas.getContext('2d');
        if (!ctx) {
            return [0];
        }
        [canvas.height, canvas.width] = [28, 28];
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, 28, 28);
        ctx.drawImage(canvasMain, 0, 0, 28, 28);
        let imageData = ctx.getImageData(0, 0, 28, 28).data;

        // Only keep one channel from rgba
        let data: number[] = [];
        for (let i = 0; i < 28*28; i=i+1) {
            data.push(imageData[i*4]);
        }

        return data;
    }

    const clearCanvas = () => {
        canvasDraw.current.clear();
        setResult("Draw a digit above!");
    }

    return (
        <>
        <nav className="navbar navbar-dark">
            <div className="container-fluid">
                <ul className="navbar-nav me-auto"></ul>
                <a className="px-md-2 link-secondary" href="https://github.com/ebosas/mnist-lambda">Github</a>
            </div>
        </nav>
        <div
            ref={canvasParent}
            className="container px-0"
        >
            <CanvasDraw
                ref={canvasDraw}
                onChange={checkDrawing}
                lazyRadius={0}
                brushRadius={20}
                brushColor="#fff"
                backgroundColor="#1C1E21"
                hideInterface={true}
                canvasWidth={420}
                canvasHeight={420}
                hideGrid={true}
            />
            <button
                onClick={clearCanvas}
                type="button"
                className="btn btn-dark mt-4 mx-2"
            >
                Clear
            </button>
        </div>
        <div className="container mt-4 mb-5">
            <Result result={result} />
        </div>
        </>
    )
}

type resultProps = {
    result: string;
}

function Result({result}: resultProps){
    return (
        <h1>{result}</h1>
    )
}

export default App;
