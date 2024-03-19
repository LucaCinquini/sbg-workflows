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
      - $(inputs.input_cmr_stac)


## Inputs to the e2e rebinning, not to each applicaiton within the workflow
inputs:

  # Generic inputs
  input_processing_labels: string[]

  input_cmr_stac: File

  # catalog inputs
  input_unity_dapa_api: string
  input_unity_dapa_client: string

  #for preprocess  step
  input_crid: string
   

  # For unity data stage-out step, unity catalog
  output_collection_id: string
  output_data_bucket: string

outputs: 
  results: 
    type: File
    outputSource: preprocess/stage_out_results

steps:
  preprocess:
    run: http://awslbdockstorestack-lb-1429770210.us-west-2.elb.amazonaws.com:9998/api/ga4gh/trs/v2/tools/%23workflow%2Fdockstore.org%2Fmike-gangl%2FSBG-unity-preprocess/versions/21/PLAIN-CWL/descriptor/%2Fworkflow.cwl
    in:
      # input configuration for stage-in
      # edl_password_type can be either 'BASE64' or 'PARAM_STORE' or 'PLAIN'
      # README available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_in:
        source: [input_cmr_stac, input_unity_dapa_client]
        valueFrom: |
          ${
              return {
                download_type: 'DAAC',
                stac_json: self[0],
                edl_password: '/sps/processing/workflows/edl_password',
                edl_username: '/sps/processing/workflows/edl_username',
                edl_password_type: 'PARAM_STORE',
                downloading_keys: 'data, data1',
                downloading_roles: '',
                log_level: '20',
                unity_client_id: self[1],
                unity_stac_auth: 'NONE'
              };
          }
      #input configuration for process
      parameters:
        source: [output_collection_id, input_crid]
        valueFrom: |
          ${
              return {
                crid: self[1],
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
  data-catalog:
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
      uploaded_files_json: preprocess/stage_out_success
    out: [results]
