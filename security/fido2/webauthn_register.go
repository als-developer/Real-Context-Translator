package main

import (
    "encoding/base64"
    "encoding/json"
    "log"
    "net/http"
    
    "github.com/go-webauthn/webauthn/webauthn"
    "github.com/go-webauthn/webauthn/protocol"
)

var webAuthn *webauthn.WebAuthn

type User struct {
    ID          []byte
    Name        string
    DisplayName string
    Credentials []webauthn.Credential
}

func (u User) WebAuthnID() []byte                        { return u.ID }
func (u User) WebAuthnName() string                      { return u.Name }
func (u User) WebAuthnDisplayName() string               { return u.DisplayName }
func (u User) WebAuthnIcon() string                      { return "" }
func (u User) WebAuthnCredentials() []webauthn.Credential { return u.Credentials }

var users = make(map[string]*User)

func init() {
    var err error
    webAuthn, err = webauthn.New(&webauthn.Config{
        RPDisplayName: "RCT-Engine Security Gateway",
        RPID:          "rct-engine.secure-bank.internal",
        RPOrigin:      "https://rct-engine.secure-bank.internal",
    })
    if err != nil {
        log.Fatal("Failed to create WebAuthn:", err)
    }
}

func BeginRegistration(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Username string `json:"username"`
        Email    string `json:"email"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    user := &User{
        ID:          []byte(req.Username),
        Name:        req.Username,
        DisplayName: req.Email,
    }
    users[req.Username] = user
    
    options, sessionData, err := webAuthn.BeginRegistration(user)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    // Store session data
    // In production, use Redis or database
    json.NewEncoder(w).Encode(options)
}

func FinishRegistration(w http.ResponseWriter, r *http.Request) {
    username := r.URL.Query().Get("username")
    user := users[username]
    if user == nil {
        http.Error(w, "User not found", http.StatusNotFound)
        return
    }
    
    credential, err := webAuthn.FinishRegistration(user, r)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    user.Credentials = append(user.Credentials, *credential)
    
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{"status": "registered"})
}

func BeginLogin(w http.ResponseWriter, r *http.Request) {
    username := r.URL.Query().Get("username")
    user := users[username]
    if user == nil {
        http.Error(w, "User not found", http.StatusNotFound)
        return
    }
    
    options, sessionData, err := webAuthn.BeginLogin(user)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    json.NewEncoder(w).Encode(options)
}

func FinishLogin(w http.ResponseWriter, r *http.Request) {
    username := r.URL.Query().Get("username")
    user := users[username]
    if user == nil {
        http.Error(w, "User not found", http.StatusNotFound)
        return
    }
    
    _, err := webAuthn.FinishLogin(user, r)
    if err != nil {
        http.Error(w, err.Error(), http.StatusUnauthorized)
        return
    }
    
    // Generate JWT token for authenticated session
    token := generateJWT(user.Name)
    json.NewEncoder(w).Encode(map[string]string{"token": token})
}

func generateJWT(username string) string {
    // JWT generation logic here
    return "jwt_token_placeholder"
}
