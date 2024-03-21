#!/usr/bin/env cwl-runner
cwlVersion: v1.1
class: Workflow
label: Workflow that executes the SBG L1 Workflow

$namespaces:
  cwltool: http://commonwl.org/cwltool#

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  MultipleInputFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - $(inputs.input_stac)



## Inputs to the e2e rebinning, not to each applicaiton within the workflow
inputs:

  # Generic inputs
  input_processing_labels: string[]

  # catalog inputs
  input_unity_dapa_api: string
  input_unity_dapa_client: string
  unity_stac_auth: string


  #for preprocess  step
  input_crid: string
  input_stac: 
    - File 
  input_aux_stac: 
    - string
    - File

  # For unity data stage-out step, unity catalog
  output_collection_id: string
  output_data_bucket: string

outputs: 
  results: 
    type: File
    outputSource: isofit/stage_out_results

steps:
  isofit:
    run: http://awslbdockstorestack-lb-1429770210.us-west-2.elb.amazonaws.com:9998/api/ga4gh/trs/v2/tools/%23workflow%2Fdockstore.org%2Fmike-gangl%2FSBG-unity-isofit/versions/18/PLAIN-CWL/descriptor/%2FDockstore.cwl
    in:
      # input configuration for stage-in
      # edl_password_type can be either 'BASE64' or 'PARAM_STORE' or 'PLAIN'
      # README available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_in:
        source: [input_stac, input_unity_dapa_client, unity_stac_auth]
        valueFrom: |
          ${
              return {
                download_type: 'S3',
                stac_json: self[0],
                unity_stac_auth: self[2],
                unity_client_id: self[1],
                downloading_roles: 'data, metadata',
                log_level: '20'
              };
          }
      #input configuration for process
      stage_aux_in:
        source: [input_aux_stac, input_unity_dapa_client]
        valueFrom: |
          ${
              return {
                download_type: 'S3',
                stac_json: self[0],
                unity_stac_auth: 'NONE',
                unity_client_id: self[1],
                downloading_roles: 'data, metadata',
                log_level: '20'
              };
          }
      parameters:
        source: [output_collection_id, input_crid]
        valueFrom: |
          ${
              return {
                crid: self[1],
                cores: 4,
                sensor: 'EMIT',
                temp_directory: '/tmp',
                output_collection: self[0]
              };
          }
      #input configuration for stage-out
      # readme available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_out:
        source: [output_data_bucket, output_collection_id]
        valueFrom: |
          ${
              return {
                aws_access_key_id: '',
                aws_region: 'us-west-2',
                aws_secret_access_key: '',
                aws_session_token: '',
                collection_id: self[1],
                staging_bucket: self[0],
                log_level: '20'
              };
          }
    out: [stage_out_results, stage_out_success, stage_out_failures]
  isofit-data-catalog:
    #run: catalog/catalog.cwl
    run: http://awslbdockstorestack-lb-1429770210.us-west-2.elb.amazonaws.com:9998/api/ga4gh/trs/v2/tools/%23workflow%2Fdockstore.org%2Fmike-gangl%2Fcatalog-trial/versions/12/PLAIN-CWL/descriptor/%2FDockstore.cwl
    in:
      unity_username:
        valueFrom: "/sps/processing/workflows/unity_username"
      unity_password:
        valueFrom: "/sps/processing/workflows/unity_password"
      password_type:
        valueFrom: "PARAM_STORE"
      unity_client_id: input_unity_dapa_client
      unity_dapa_api: input_unity_dapa_api
      uploaded_files_json: isofit/stage_out_success
    out: [results]
