"""
### CODE OWNERS: Ben Copeland

### OBJECTIVE:
  Pull eCQM value sets from web API

### DEVELOPER NOTES:
  Meant to be called from command line
  Value set CSV input requires "measure_name", "value_set_name", and "value_set_oid"
"""

import csv
import requests
import xml.etree.ElementTree as ET
import argparse
from pathlib import Path

URL_BASE_AUTH = r'https://vsac.nlm.nih.gov/vsac/ws/'
URL_RETRIEVE_VALUE_SETS = r'https://vsac.nlm.nih.gov/vsac/svs/RetrieveMultipleValueSets'
URL_AUTH_SERVICE = r'http://umlsks.nlm.nih.gov'

# LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE

def _parse_oid_request(
        oid: str,
    ):
    """Convert an OID request into structured rows of data"""
    iter_output = []
    service_ticket = requests.post(
        URL_BASE_AUTH + 'Ticket/{}'.format(TGT),
        data={'service': URL_AUTH_SERVICE},
    )

    value_set = requests.get(
        URL_RETRIEVE_VALUE_SETS,
        params={
            'id': oid,
            'ticket': service_ticket.text,
        },
    )
    elements = ET.fromstring(value_set.text)
    ns = {"ns0":"urn:ihe:iti:svs:2008"}
    for concept in elements.findall(".//ns0:ConceptList/ns0:Concept",ns):
        row = {}
        for field, info in concept.items():
            row[field] = info
        iter_output.append(row)

    return iter_output

def _limit_iter_output(line_dict)-> dict:
    code_system_map = {
        'SNOMEDCT': 'SNOMEDCT',
        'CPT': 'CPT',
        'HCPCS': 'HCPCS',
        'ICD10CM': 'ICD10CM-Diag',
        'ICD10PCS': 'ICD10CM-Proc',
        'ICD9CM': 'ICD9CM-Diag',
        'ICD9PCS': 'ICD9CM-Proc',
        'LOINC':'LOINC',
        'UBREV': 'UBREV',
    }

    output_dict = {
        'Measure': line_dict['Measure'],
        'Component': line_dict['component_name'],
        'CodeSystem': code_system_map[line_dict['codeSystemName']],
        'Code': line_dict['code'].replace('.', ''),
        'Grouping_ID': None,
        'Diag_Type': None,
    }

    return output_dict


def get_argparser():
    """Setup the command line argument parser"""
    parser = argparse.ArgumentParser(
        description="Pull down eCQM value sets",
    )
    parser.add_argument('-u', '--username', help='UMLS Terminal Services User Name')
    parser.add_argument('-p', '--password', help='UMLS Terminal Services Password')
    parser.add_argument('-i', '--path_input_value_sets', help='Definition of value sets to be pulled')
    parser.add_argument('-o', '--path_output', help='Path of output file')
    return parser

if __name__ == '__main__':
    ARGPARSER = get_argparser()
    ARGS = ARGPARSER.parse_args()

    TICKET_GETTER = requests.post(
        URL_BASE_AUTH + 'Ticket',
        headers={"Accept": "text/plain", "User-Agent":"python"},
        data={
            'username': ARGS.username,
            'password': ARGS.password,
        },
    )
    TGT = TICKET_GETTER.text
    PATH_OUTPUT_FILE = Path(ARGS.path_output)
    PATH_INPUT_FILE = Path(ARGS.path_input_value_sets)
    with PATH_OUTPUT_FILE.open('w', newline='') as fh_out, PATH_INPUT_FILE.open('r') as fh_in:
        reader = csv.DictReader(
            fh_in,
        )
        iter_output = []
        for dict_in_line in reader:
            iter_oid_codes = _parse_oid_request(dict_in_line['value_set_oid'])
            for output_row in iter_oid_codes:
                output_row.update(
                    dict_in_line
                )
                iter_output.append(
                    output_row
                )

        writer = csv.DictWriter(
            fh_out,
            fieldnames=[
                'measure_name',
                'value_set_name',
                'value_set_oid',
                'code',
                'codeSystem',
                'codeSystemName',
                'codeSystemVersion',
                'displayName',
                ]
        )
        writer.writeheader()
        writer.writerows(iter_output)
