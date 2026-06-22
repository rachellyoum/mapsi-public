
import SwiftUI
 
extension Color {
    static let mapsiGreen    = Color(red: 0.106, green: 0.369, blue: 0.208)
    static let mapsiGray     = Color(red: 0.95,  green: 0.95,  blue: 0.95)
    static let mapsiTextGray = Color(red: 0.6,   green: 0.6,   blue: 0.6)
}
 
struct FlightView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FlightViewModel()
 
    @State private var showDeparturePicker = false
    @State private var showReturnPicker    = false
    @State private var showTravelerSheet   = false
    @State private var showClassSheet      = false
 
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
 
                ScrollView {
                    VStack(spacing: 0) {
                        headerView
                        tripTypeSelector
                        searchFormCard
                        searchButton
                        Spacer(minLength: 40)
                    }
                }
 
                NavigationLink(
                    destination: FlightListView(viewModel: viewModel),
                    isActive: $viewModel.showResults
                ) { EmptyView() }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showDeparturePicker) {
            DatePickerSheet(title: "Departure Date", date: $viewModel.departureDate)
        }
        .sheet(isPresented: $showReturnPicker) {
            DatePickerSheet(title: "Return Date", date: $viewModel.returnDate)
        }
        .sheet(isPresented: $showTravelerSheet) { TravelerSheet(viewModel: viewModel) }
        .sheet(isPresented: $showClassSheet)    { CabinClassSheet(viewModel: viewModel) }
    }
 
    // MARK: - Header
 
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
            }
            Spacer()
            Text("MAPSI")
                .font(.custom("DynaPuff-Medium", size: 40))
                .padding(.bottom, 20)
                .foregroundColor(Color(hex: "064229"))
            Spacer()
            Color.clear.frame(width: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
 
    // MARK: - Trip Type Selector
 
    private var tripTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Flights")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)
 
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(TripType.allCases, id: \.self) { type in
                        Button(action: { viewModel.tripType = type }) {
                            VStack(spacing: 4) {
                                Text(type.rawValue)
                                    .font(.system(size: 14,
                                                  weight: viewModel.tripType == type ? .semibold : .regular))
                                    .foregroundColor(viewModel.tripType == type ? .mapsiGreen : .mapsiTextGray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(viewModel.tripType == type ? .mapsiGreen : .clear)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            Divider()
        }
        .padding(.top, 12)
    }
 
    // MARK: - Search Form
 
    private var searchFormCard: some View {
        VStack(spacing: 0) {
 
            // From / To with autocomplete
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.mapsiGreen, lineWidth: 1.5)
                .frame(height: 150)
                .overlay(
                    VStack(spacing: 0) {
                        // FROM
                        HStack {
                            TextField("From (city or airport)", text: $viewModel.fromText)
                                .font(.system(size: 15))
                                .disableAutocorrection(true)
                                .onChange(of: viewModel.fromText) { viewModel.onFromTextChanged($0) }
                            // 선택됐으면 체크 표시
                            if !viewModel.fromCode.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.mapsiGreen)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 74)
 
                        Divider().overlay(
                            Button(action: { viewModel.swapCities() }) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.mapsiGreen)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.mapsiGreen, lineWidth: 1.2))
                            }
                        )
 
                        // TO
                        HStack {
                            TextField("To (city or airport)", text: $viewModel.toText)
                                .font(.system(size: 15))
                                .disableAutocorrection(true)
                                .onChange(of: viewModel.toText) { viewModel.onToTextChanged($0) }
                            if !viewModel.toCode.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.mapsiGreen)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 74)
                    }
                )
                .padding(.horizontal, 20)
 
            // FROM 자동완성 드롭다운
            if viewModel.showFromSuggestions {
                AirportDropdown(results: viewModel.fromSuggestions) { airport in
                    viewModel.selectFrom(airport)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
 
            // TO 자동완성 드롭다운
            if viewModel.showToSuggestions {
                AirportDropdown(results: viewModel.toSuggestions) { airport in
                    viewModel.selectTo(airport)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
 
            // Date pickers
            HStack(spacing: 12) {
                DateFieldButton(label: "Departure", value: viewModel.departureDateDisplay) {
                    showDeparturePicker = true
                }
                if viewModel.tripType == .roundTrip {
                    DateFieldButton(label: "Return", value: viewModel.returnDateDisplay) {
                        showReturnPicker = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
 
            // Travelers + Class
            HStack(spacing: 12) {
                InfoFieldButton(label: "Travelers", value: viewModel.travelersDisplay) {
                    showTravelerSheet = true
                }
                InfoFieldButton(label: "Class", value: viewModel.cabinClass.rawValue) {
                    showClassSheet = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .padding(.top, 20)
    }
 
    // MARK: - Search Button
 
    private var searchButton: some View {
        Button(action: { viewModel.searchFlights() }) {
            ZStack {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Search Flights")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(viewModel.isSearchEnabled ? Color.mapsiGreen : Color.mapsiGreen.opacity(0.4))
            .cornerRadius(12)
        }
        .disabled(!viewModel.isSearchEnabled || viewModel.isLoading || viewModel.isSearching)
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }
}
 
// MARK: - Airport Dropdown
 
struct AirportDropdown: View {
    let results: [AirportResult]
    let onSelect: (AirportResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(results.prefix(5)) { airport in
                Button(action: { onSelect(airport) }) {
                    HStack(spacing: 12) {

                        // IATA badge
                        Text(airport.iata)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.mapsiGreen)
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(airport.displayTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)

                            Text(airport.displaySubtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                if airport.id != results.prefix(5).last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
// MARK: - Reusable Buttons
 
struct DateFieldButton: View {
    let label: String
    let value: String
    let action: () -> Void
 
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 11)).foregroundColor(.mapsiTextGray)
                    Text(value).font(.system(size: 14)).foregroundColor(.black)
                }
                Spacer()
                Image(systemName: "calendar").font(.system(size: 13)).foregroundColor(.mapsiGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.mapsiGray)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
    }
}
 
struct InfoFieldButton: View {
    let label: String
    let value: String
    let action: () -> Void
 
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 11)).foregroundColor(.mapsiTextGray)
                    Text(value).font(.system(size: 14)).foregroundColor(.black)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(.mapsiGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.mapsiGray)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
    }
}
 
// MARK: - Sheets
 
struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundColor(.mapsiGreen).font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical).tint(.mapsiGreen).padding(.horizontal, 12)
            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
 
struct TravelerSheet: View {
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Traveller").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundColor(.mapsiGreen).font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 24)
 
            HStack(spacing: 32) {
                Button(action: { viewModel.decrementTravelers() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(viewModel.travelers > 1 ? .mapsiGreen : .gray.opacity(0.4))
                }
                .disabled(viewModel.travelers <= 1)
 
                Text("\(viewModel.travelers)")
                    .font(.system(size: 40, weight: .bold)).frame(minWidth: 50)
 
                Button(action: { viewModel.incrementTravelers() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(viewModel.travelers < 9 ? .mapsiGreen : .gray.opacity(0.4))
                }
                .disabled(viewModel.travelers >= 9)
            }
            .padding(.vertical, 16)
 
            Text("Passengers").font(.system(size: 14)).foregroundColor(.mapsiTextGray)
            Spacer()
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}
 
struct CabinClassSheet: View {
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Class").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundColor(.mapsiGreen).font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
 
            ForEach(CabinClass.allCases, id: \.self) { cabin in
                Button(action: { viewModel.cabinClass = cabin; dismiss() }) {
                    HStack {
                        Text(cabin.rawValue).font(.system(size: 16)).foregroundColor(.black)
                        Spacer()
                        if viewModel.cabinClass == cabin {
                            Image(systemName: "checkmark")
                                .foregroundColor(.mapsiGreen)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
                Divider().padding(.horizontal, 20)
            }
            Spacer()
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}

#Preview { FlightView() }
