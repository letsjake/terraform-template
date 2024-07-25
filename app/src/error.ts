import { Request, Response, Router } from 'express';
import axios, { AxiosError } from 'axios';

export const errorHandler = (error: any, res: Response) => {
    if (axios.isAxiosError(error)) {
        const axiosError = error as AxiosError;

        if (axiosError.response) {
        switch (axiosError.response.status) {
            case 400:
            res.status(400).json({ error: 'Bad Request', message: axiosError.response.data });
            break;
            case 401:
            res.status(401).json({ error: 'Unauthorized', message: axiosError.response.data });
            break;
            case 403:
            res.status(403).json({ error: 'Forbidden', message: axiosError.response.data });
            break;
            case 404:
            res.status(404).json({ error: 'Not Found', message: axiosError.response.data });
            break;
            case 429:
            res.status(429).json({ error: 'Too Many Requests', message: axiosError.response.data });
            break;
            case 500:
            res.status(500).json({ error: 'Internal Server Error', message: axiosError.response.data });
            break;
            default:
            res.status(axiosError.response.status).json({ error: 'An error occurred', message: axiosError.response.data });
            break;
        }
        } else if (axiosError.request) {
        // The request was made but no response was received
        res.status(503).json({ error: 'Service Unavailable', message: 'No response received from server' });
        } else {
        // Something happened in setting up the request that triggered an Error
        res.status(500).json({ error: 'Internal Server Error', message: axiosError.message });
        }
    } else {
        res.status(500).json({ error: 'Internal Server Error', message: error.message });
    }
};