package com.cybercircuit.client;

/** A lightweight UI definition for CyberCircuit's in-game module manager. */
public record CyberCircuitModule(String name, String category, String description, boolean external, boolean enabled) {
    public CyberCircuitModule withEnabled(boolean value) {
        return new CyberCircuitModule(name, category, description, external, value);
    }
}
