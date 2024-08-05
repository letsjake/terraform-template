import express from 'express';

import routes from './routes';

const app = express();

app.use(express.json());

app.use('/', routes);

app.use((req: express.Request, res: express.Response, next: express.NextFunction) => {
  res.status(404).send();
});

app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  res.status(err.status || 500).send();
});

// Start the server locally if not in a serverless environment
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}, hello world! `);
});

export default app;