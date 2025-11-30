#!/bin/bash

echo "Generating traffic to all services..."
echo ""

for i in {1..20}; do
    echo "Request batch $i/20"
    
    curl -s http://localhost:5001/api/hello > /dev/null && echo "  C# service"
    curl -s http://localhost:5002/api/hello > /dev/null && echo "  Go service"
    curl -s http://localhost:5003/api/hello > /dev/null && echo "  Python service"
    curl -s http://localhost:5004/api/hello > /dev/null && echo "  Rust service"
    curl -s http://localhost:5005/api/hello > /dev/null && echo "  C++ service"
    
    echo ""
    sleep 1
done

echo "Traffic generation complete"
echo "View logs and traces at: http://localhost:3000"
