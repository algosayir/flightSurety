
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    
        // Read transaction
        contract.updateFlightStatus((error, result) => {
            console.log(error,result);
            display('Flight Status', 'Flight stutus update', [ { label: 'Flight Status', error: error, value: "result.flight + ' ' + result.status"} ]);
        });

        // User-submitted transaction
        DOM.elid('purchase-insurance').addEventListener('click', () => {
            let flight = DOM.elid('flights-list-insurance').value;
            let insurance_value = DOM.elid('insurance-value').value;
            //console.log("I am here");
            // Write transaction
            contract.purchageFlightInsurance(flight, insurance_value, (error, result) => {
                display('Purchase Insurance', 'Purchase Insurance', [ { label: 'Purchase Insurance', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flights-list').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })
    
        
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







