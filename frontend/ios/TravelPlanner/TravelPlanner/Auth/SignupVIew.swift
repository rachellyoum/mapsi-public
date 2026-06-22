//
//  Signup.swift
//  TravelPlanner
//
//  Created by Kylie Kim on 2026-02-21.
//


import SwiftUI

struct SignUpView: View {
    
    @StateObject private var vm = SignUpViewModel()
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) var dismiss
    
    
    @State private var showSuccessAlert = false
    
    var body: some View {
        
        VStack {
            
            Spacer()
            
            Text("MAPSI")
                .font(.custom("DynaPuff-Medium", size: 40))
                .padding(.bottom, 20)
            
            Text("Sign up")
                .font(.headline)
            
            if !vm.errorMsg.isEmpty {
                Text(vm.errorMsg)
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
            
            TextField("Full Name", text: $vm.userName)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
            TextField("email@domain.com", text: $vm.email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
            
            SecureField("Password", text: $vm.password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
            
            SecureField("Confirm Password", text: $vm.confirmPwd)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
            
            
            Button {
                vm.signUp { success in
                    if success {
                        showSuccessAlert = true // 👉 로그인 처리 X
                    }
                }
            } label: {
                Text(vm.isLoading ? "Creating ..." : "Sign up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.0, green: 0.35, blue: 0.15))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            Spacer()
            
            // MARK: - Google
            Button {
                vm.signInWithGoogle { success in
                    if success {
                        isLoggedIn = true
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
            
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.gray)
                
                Button("Sign in") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding(.bottom, 20)
        }
        
       
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your account has been created successfully. Please sign in.")
        }
    }
}
#Preview {
    SignUpView(isLoggedIn: .constant(false))
}
