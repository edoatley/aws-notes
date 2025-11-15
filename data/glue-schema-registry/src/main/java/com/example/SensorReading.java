package com.example;

import com.fasterxml.jackson.annotation.JsonProperty;

public class SensorReading {
    @JsonProperty("sensorId")
    private String sensorId;
    
    @JsonProperty("temperature")
    private Double temperature;
    
    @JsonProperty("humidity")
    private Double humidity;
    
    @JsonProperty("timestamp")
    private Long timestamp;
    
    // Default constructor (required for JSON deserialization)
    public SensorReading() {
    }
    
    // Constructor with all fields
    public SensorReading(String sensorId, Double temperature, Double humidity, Long timestamp) {
        this.sensorId = sensorId;
        this.temperature = temperature;
        this.humidity = humidity;
        this.timestamp = timestamp;
    }
    
    // Getters and setters
    public String getSensorId() {
        return sensorId;
    }
    
    public void setSensorId(String sensorId) {
        this.sensorId = sensorId;
    }
    
    public Double getTemperature() {
        return temperature;
    }
    
    public void setTemperature(Double temperature) {
        this.temperature = temperature;
    }
    
    public Double getHumidity() {
        return humidity;
    }
    
    public void setHumidity(Double humidity) {
        this.humidity = humidity;
    }
    
    public Long getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(Long timestamp) {
        this.timestamp = timestamp;
    }
    
    @Override
    public String toString() {
        return String.format("SensorReading{sensorId='%s', temperature=%.2f, humidity=%.2f, timestamp=%d}",
                sensorId, temperature, humidity, timestamp);
    }
}

