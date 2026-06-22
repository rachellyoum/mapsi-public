//
//  Login.swift
//  TravelPlanner
//
//  Created by Kylie Kim on 2026-02-21.
//


import SwiftUI

struct LoginView: View {
    
    @StateObject private var vm = LoginViewModel()
    @State private var showSignUp = false
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        
        VStack {
            
            Spacer()
            
            // MARK: - Logo
            Text("MAPSI")
                .font(.custom("DynaPuff-Medium", size: 40))
                .padding(.bottom, 20)
                .foregroundColor(Color(hex:"064229"))
            
            // MARK: - Title
            Text("Sign in")
                .font(.headline)
            
            //에러 메시지 띄우기 전에 미리 회색 바탕으로 안내 멘트 적기 (**)
            
            if !vm.errorMsg.isEmpty {
                Text(vm.errorMsg)
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
            
            // MARK: - Email
            TextField("Email", text: $vm.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
            // MARK: - Password
            SecureField("Password", text: $vm.password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
            
            // MARK: - Remember Me
            CheckboxView(isChecked: $vm.rememberMe)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 10)
            
            // MARK: - Sign In Button
            Button {
                print("Login tapped")
                vm.login { success in
                    if success {
                        DispatchQueue.main.async {
                            isLoggedIn = true
                        }
                    }
                }
            } label: {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex:"064229"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            .padding(.horizontal)
            .padding(.top, 20)
            
            // MARK: - Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("or")
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            
            // MARK: - Google
            Button {
                vm.signInWithGoogle { success in
                    if success {
                        DispatchQueue.main.async {
                            isLoggedIn = true
                        }
                    }
                }
            } label: {
                HStack {
                    Image("google")
                        .resizable()
                        .frame(width: 20, height: 20)

                    Text(vm.isLoading ? "Connecting..." : "Continue with Google")
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
            }
            .disabled(vm.isLoading)
            .padding(.horizontal)
            
            // MARK: - Apple
            Button {
                print("Apple login")
            } label: {
                HStack {
                    Image("apple")
                        .resizable()
                        .frame(width: 20, height: 20)
                    
                    Text("Continue with Apple")
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
            
            // MARK: - Sign Up
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.gray)
                
                Button("Sign up") {
                    showSignUp = true
                }
                .fontWeight(.semibold)
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(isLoggedIn: $isLoggedIn)
        }
    }
}
struct CheckboxView: View {
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? Color(hex:"064229") : .gray)
                
                Text("Remember me")
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View{
        LoginView(isLoggedIn: .constant(false))
    }
}
