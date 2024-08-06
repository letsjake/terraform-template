import { Router } from 'express';
import { ip } from 'address'

import { errorHandler } from '../error';

const router = Router();

router.get('/', (req, res) => {
    try {
        const serverIp = ip();
        res.status(200).send(`bye, World! Server IP: ${serverIp}`);
    } catch (error) {
        errorHandler(error, res);
    }
});

export default router;