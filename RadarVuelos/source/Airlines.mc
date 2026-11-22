import Toybox.Lang;

// Nombres legibles a partir del indicativo OACI (3 letras) y del código de tipo de avión.
module Airlines {
    const NAMES = {
        "IBE" => "Iberia", "IBS" => "Iberia Express", "ANE" => "Air Nostrum", "VLG" => "Vueling",
        "AEA" => "Air Europa", "IBB" => "Binter", "VOE" => "Volotea", "EVE" => "Evelop",
        "RYR" => "Ryanair", "RUK" => "Ryanair", "EZY" => "easyJet", "EJU" => "easyJet",
        "EZS" => "easyJet", "WZZ" => "Wizz Air", "BAW" => "British Airways", "SHT" => "British Airways",
        "AFR" => "Air France", "DLH" => "Lufthansa", "EWG" => "Eurowings", "KLM" => "KLM",
        "TAP" => "TAP Portugal", "SWR" => "Swiss", "ITY" => "ITA Airways", "AUA" => "Austrian",
        "BEL" => "Brussels", "SAS" => "SAS", "NOZ" => "Norwegian", "NSZ" => "Norwegian",
        "TVF" => "Transavia", "TRA" => "Transavia", "BTI" => "airBaltic", "LOT" => "LOT",
        "FIN" => "Finnair", "EIN" => "Aer Lingus", "CFG" => "Condor", "TOM" => "TUI",
        "TUI" => "TUI", "UAE" => "Emirates", "QTR" => "Qatar Airways", "ETD" => "Etihad",
        "THY" => "Turkish", "PGT" => "Pegasus", "RAM" => "Royal Air Maroc", "MSR" => "EgyptAir",
        "ELY" => "El Al", "SVA" => "Saudia", "AAL" => "American", "UAL" => "United",
        "DAL" => "Delta", "ACA" => "Air Canada", "AVA" => "Avianca", "LAN" => "LATAM",
        "TAM" => "LATAM", "ARG" => "Aerolíneas Arg.", "AMX" => "Aeroméxico", "CPA" => "Cathay",
        "SIA" => "Singapore", "CCA" => "Air China", "JAL" => "JAL", "ANA" => "ANA",
        "DHK" => "DHL", "BCS" => "DHL", "FDX" => "FedEx", "UPS" => "UPS", "SWT" => "Swiftair",
        "GEC" => "Lufthansa Cargo", "CLX" => "Cargolux", "NJE" => "NetJets", "AEH" => "Air Europa Exp.",
        "PLM" => "Wamos Air", "IBK" => "Norwegian", "AIZ" => "Arkia", "HOP" => "Air France Hop"
    };

    const TYPES = {
        "A319" => "Airbus A319", "A320" => "Airbus A320", "A321" => "Airbus A321",
        "A20N" => "A320neo", "A21N" => "A321neo", "A19N" => "A319neo", "A332" => "Airbus A330",
        "A333" => "Airbus A330", "A339" => "A330neo", "A359" => "Airbus A350", "A35K" => "A350-1000",
        "A388" => "Airbus A380", "BCS3" => "Airbus A220", "BCS1" => "Airbus A220",
        "B737" => "Boeing 737", "B738" => "Boeing 737", "B739" => "Boeing 737", "B38M" => "737 MAX",
        "B39M" => "737 MAX", "B744" => "Boeing 747", "B748" => "Boeing 747", "B752" => "Boeing 757",
        "B763" => "Boeing 767", "B772" => "Boeing 777", "B77W" => "Boeing 777", "B77L" => "Boeing 777",
        "B788" => "Boeing 787", "B789" => "Boeing 787", "B78X" => "Boeing 787",
        "E190" => "Embraer 190", "E195" => "Embraer 195", "E290" => "Embraer E2", "E295" => "Embraer E2",
        "CRJ9" => "CRJ-900", "CRJ1" => "CRJ-1000", "AT72" => "ATR 72", "AT76" => "ATR 72",
        "AT75" => "ATR 72", "DH8D" => "Dash 8", "C25A" => "Citation", "C56X" => "Citation",
        "EC35" => "Helicóptero", "EC45" => "Helicóptero", "EC30" => "Helicóptero",
        "AS50" => "Helicóptero", "H160" => "Helicóptero", "A139" => "Helicóptero"
    };

    // Solo si el indicativo empieza por tres letras y sigue con un dígito (IBE0258, VLG12AB).
    function airline(callsign as String) as String {
        if (callsign.length() < 4) { return ""; }
        var chars = callsign.toCharArray();
        for (var i = 0; i < 3; i++) {
            var c = chars[i].toNumber();
            if (c < 65 || c > 90) { return ""; }
        }
        var d = chars[3].toNumber();
        if (d < 48 || d > 57) { return ""; }
        var name = NAMES[callsign.substring(0, 3)];
        return name == null ? "" : name;
    }

    function typeName(code as String) as String {
        if (code.length() == 0) { return ""; }
        var name = TYPES[code];
        return name == null ? code : name;
    }
}
