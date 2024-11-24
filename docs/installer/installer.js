/**
 * KissPanel Installer Configuration
 * 
 * This script handles:
 * - Form state management
 * - Input validation
 * - Command generation
 * - Clipboard operations
 * - Local storage persistence
 */

// Track default states
const defaults = {
    // System Configuration
    port: '8083',
    language: 'en',
    hostname: '',
    email: '',
    password: '',
    quota: false,
    api: true,
    interactive: true,
    force: false,

    // Web Server
    nginx: true,
    apache: true,
    phpfpm: true,
    multiphp: false,

    // Database
    sqlite: true,
    mariadb: true,
    mysql8: false,
    postgresql: false,

    // Mail
    exim: true,
    dovecot: true,
    sieve: false,
    clamav: true,
    spamassassin: true,

    // Security
    iptables: true,
    fail2ban: true,

    // FTP
    vsftpd: true,
    proftpd: false,

    // DNS
    bind: true
};

// Validation functions
function validatePort(port) {
    const portNum = parseInt(port);
    return !isNaN(portNum) && portNum >= 2000 && portNum <= 9999;
}

function validateHostname(hostname) {
    const pattern = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
    return pattern.test(hostname);
}

function validateEmail(email) {
    const pattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return pattern.test(email);
}

function validatePassword(password) {
    if (!password) return true; // Allow empty password
    if (!/^[a-zA-Z]/.test(password)) return false; // Must start with letter
    if (!/[A-Z]/.test(password)) return false; // Must contain uppercase
    if (!/[a-z]/.test(password)) return false; // Must contain lowercase
    if (!/[0-9]/.test(password)) return false; // Must contain number
    return true;
}
// State management functions
function saveState() {
    const state = {};
    document.querySelectorAll('[id^="enable_"]').forEach(checkbox => {
        state[checkbox.id] = checkbox.checked;
        if (checkbox.checked) {
            const inputId = checkbox.id.replace('enable_', '');
            const input = document.getElementById(inputId);
            state[inputId] = input.value;
        }
    });

    // Save component states
    Object.keys(defaults).forEach(key => {
        const element = document.getElementById(key);
        if (element && element.type === 'checkbox') {
            state[key] = element.checked;
        }
    });

    localStorage.setItem('installerState', JSON.stringify(state));
}

function loadState() {
    const savedState = localStorage.getItem('installerState');
    if (savedState) {
        const state = JSON.parse(savedState);
        
        // Load system configuration states
        Object.entries(state).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                if (id.startsWith('enable_')) {
                    element.checked = value;
                    if (value) {
                        toggleInput(id);
                    }
                } else {
                    if (element.type === 'checkbox') {
                        element.checked = value;
                    } else {
                        element.value = value;
                    }
                }
            }
        });
    }
}

// Validate input and update UI
function validateInput(input) {
    let isValid = true;
    const inputId = input.id;
    const value = input.value;

    switch(inputId) {
        case 'port':
            isValid = validatePort(value);
            break;
        case 'hostname':
            isValid = validateHostname(value);
            break;
        case 'email':
            isValid = validateEmail(value);
            break;
        case 'password':
            isValid = validatePassword(value);
            break;
    }

    if (!isValid) {
        input.classList.add('border-red-500', 'focus:border-red-500', 'focus:ring-red-500');
        input.classList.remove('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500');
    } else {
        input.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500');
        input.classList.add('border-gray-300', 'focus:border-blue-500', 'focus:ring-blue-500');
    }

    return isValid;
}

// Update command based on form state
function updateCommand() {
    let cmd = 'bash kp-install.sh';
    const params = [];

    // System Configuration
    document.querySelectorAll('[id^="enable_"]').forEach(checkbox => {
        if (checkbox.checked) {
            const inputId = checkbox.id.replace('enable_', '');
            const input = document.getElementById(inputId);
            if (!validateInput(input)) return;
            const value = input.value;
            if (value && value !== defaults[inputId]) {
                params.push(`--${inputId} ${value}`);
            }
        }
    });

    // Components
    Object.entries(defaults).forEach(([key, defaultValue]) => {
        if (!key.startsWith('enable_')) {
            const element = document.getElementById(key);
            if (element && element.type === 'checkbox') {
                if (defaultValue && !element.checked) {
                    params.push(`--${key} no`);
                } else if (!defaultValue && element.checked) {
                    params.push(`--${key} yes`);
                }
            }
        }
    });

    if (params.length) {
        cmd += ' ' + params.join(' ');
    }

    document.getElementById('command').textContent = cmd;
}

// Generate random password
function generatePassword() {
    const length = 16;
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#$%^&*';
    
    // Start with a letter (randomly upper or lower)
    let password = Math.random() < 0.5 
        ? uppercase.charAt(Math.floor(Math.random() * uppercase.length))
        : lowercase.charAt(Math.floor(Math.random() * lowercase.length));
    
    // Ensure at least one of each required type
    password += lowercase.charAt(Math.floor(Math.random() * lowercase.length));
    password += uppercase.charAt(Math.floor(Math.random() * uppercase.length));
    password += numbers.charAt(Math.floor(Math.random() * numbers.length));
    password += symbols.charAt(Math.floor(Math.random() * symbols.length));

    // Fill the rest randomly
    const allChars = lowercase + uppercase + numbers + symbols;
    for (let i = password.length; i < length; i++) {
        password += allChars.charAt(Math.floor(Math.random() * allChars.length));
    }

    // Shuffle the password (keeping first character as a letter)
    const firstChar = password.charAt(0);
    const rest = password.slice(1).split('').sort(() => Math.random() - 0.5).join('');
    password = firstChar + rest;
    
    const passwordInput = document.getElementById('password');
    passwordInput.value = password;
    validateInput(passwordInput);
    saveState();
    updateCommand();
}

// Copy text to clipboard
function copyText(elementId) {
    const element = document.getElementById(elementId);
    const text = element.textContent;
    
    navigator.clipboard.writeText(text.trim()).then(() => {
        const buttonContainer = element.nextElementSibling;
        const button = buttonContainer.querySelector('button:last-child') || buttonContainer;
        const originalText = button.textContent;
        button.textContent = 'Copied!';
        button.classList.add('bg-green-600');
        
        setTimeout(() => {
            button.textContent = originalText;
            button.classList.remove('bg-green-600');
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy text: ', err);
        alert('Failed to copy to clipboard');
    });
}

// Add this new function for reset functionality
function resetInstaller() {
    localStorage.removeItem('installerState');
    document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
        if (checkbox.id.startsWith('enable_')) {
            checkbox.checked = false;
            toggleInput(checkbox.id);
        } else {
            checkbox.checked = defaults[checkbox.id] || false;
        }
    });
    document.getElementById('command').textContent = 'bash kp-install.sh';
}

// Toggle input fields based on checkbox state
function toggleInput(checkboxId) {
    const checkbox = document.getElementById(checkboxId);
    const inputId = checkboxId.replace('enable_', '');
    const inputContainer = document.getElementById(`${inputId}_input_container`);
    const input = document.getElementById(inputId);
    
    inputContainer.classList.toggle('hidden', !checkbox.checked);
    inputContainer.classList.toggle('mt-3', checkbox.checked);
    input.disabled = !checkbox.checked;
    
    if (checkbox.checked) {
        input.focus();
    }
    
    saveState();
    updateCommand();
}

// Initialize event listeners
document.addEventListener('DOMContentLoaded', function() {
    // Add listeners for enable checkboxes
    document.querySelectorAll('[id^="enable_"]').forEach(checkbox => {
        checkbox.addEventListener('change', () => toggleInput(checkbox.id));
    });

    // Add listeners for all inputs and checkboxes
    document.querySelectorAll('input, select').forEach(element => {
        if (element.id.startsWith('enable_')) return;
        
        element.addEventListener('change', () => {
            if (validateInput(element)) {
                updateCommand();
                saveState();
            }
        });
        if (element.type === 'text' || element.type === 'email') {
            element.addEventListener('input', () => {
                if (validateInput(element)) {
                    updateCommand();
                    saveState();
                }
            });
        }
    });

    // Load saved state
    loadState();
    // Initial command update
    updateCommand();
});