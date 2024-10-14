/** @type {import('tailwindcss').Config} */



// --primary: #2c2c2c;
// --secondary: #424050;
// --accent: #8685ef;

// --text-primary: #faf7ff;
// --text-secondary: #2b2b2b;


export default {
    content: [
        "./index.html",
        "./src/**/*.{svelte,js,ts,jsx,tsx}",
      ],
  theme: {
    extend: {
        colors: {
            'primary': '#252525',
            'secondary': '#3C3C3C',
            'accent': '#37b24d',

            'success': '#51cf66',
            'error': '#ff6b6b',

            'txt-primary': '#faf7ff',
            'txt-secondary': '#2b2b2b',
        },
    },
  },
  plugins: [],
}

