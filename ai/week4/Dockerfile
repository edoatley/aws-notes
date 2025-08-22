# ---- Builder Stage ----
# This stage installs build tools and compiles the python dependencies
FROM python:3.11-slim as builder

# Install system dependencies required for building wheels
RUN apt-get update && apt-get install -y --no-install-recommends build-essential cmake && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Set build arguments for llama-cpp-python
ARG CMAKE_ARGS="-DLLAMA_CUBLAS=OFF -DLLAMA_OPENBLAS=ON"

# Copy only the requirements file and install dependencies
COPY ./requirements.txt .
RUN pip install --no-cache-dir --prefix="/install" -r requirements.txt

# ---- Final Stage ----
# This stage creates the final, lean production image
FROM python:3.11-slim

# Install runtime dependencies for llama-cpp-python (OpenMP)
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the installed python packages from the builder stage
COPY --from=builder /install /usr/local

# Copy the application code and model files into the container
COPY ./app /app
COPY ./models /app/models

# Expose the port the app runs on
EXPOSE 5000

# Define the command to run the application
# Use gunicorn for a production-ready server, binding to all interfaces on port 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--preload", "--timeout", "300", "main:app"]