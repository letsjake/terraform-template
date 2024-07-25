# Use the official Node.js image as the base image
FROM node:18-alpine

# Set the working directory
WORKDIR /usr/src/app

# Copy the package.json and yarn.lock files to the working directory
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install

# Copy the rest of the application source code to the working directory
COPY . .

# Build the TypeScript code
RUN yarn build

# Expose the port the app runs on
EXPOSE 80

# Start the application
CMD ["yarn", "start"]
