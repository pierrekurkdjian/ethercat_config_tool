fs     = require 'fs'
yargs  = require 'yargs'
xml2js = require 'xml2js'

modelFile = Object

objects      = Array()
dataTypes    = Array()

module_name  = Array()
product_name = Array()
product_code = Array()
revision_id  = Array()
rx_pdos      = Array()
tx_pdos      = Array()
sync_manager = ""

# catalogFileModule = Array()


class EthercatApp

  display_objects_catalog = (sdo, module_id) ->
    j         = 0
    k         = 0
    buffer    = ""
    data_type = sdo['Type']
    index     = sdo['Index']
    #for(j=0;j<dataTypes[module_id].length;j++){
    for j in [0..dataTypes[module_id].length-1]
      if data_type.toString().replace(/\r?\n$/, '') == dataTypes[module_id][j]['Name'].toString().replace(/\r?\n$/, '')
        #for(k=0;k<100;k++){
        for k in [0..100-1]
          if dataTypes[module_id][j]['SubItem'] != undefined && dataTypes[module_id][j]['SubItem'][k] != undefined && dataTypes[module_id][j]['SubItem'][k]['SubIdx'] != undefined
            name       = dataTypes[module_id][j]['SubItem'][k]['Name']
            sub_index  = dataTypes[module_id][j]['SubItem'][k]['SubIdx']
            bit        = 0
            bit_length = dataTypes[module_id][j]['SubItem'][k]['BitSize']
            access     = dataTypes[module_id][j]['SubItem'][k]['Flags'][0]['Access']

            buffer    += '\t\t\t\t\t\t\t\t{ name: ' + ('"' + name.toString() + '"').padEnd(35,' ') + ', index: ' + index.toString().replace('#', '0')
            buffer    += ', sub_index: ' + sub_index.toString().replace(/\D/g,'') + ', bit: ' + bit + ', bit_length: ' + bit_length + ', access: "' + access + '" }\n'

    return buffer


  get_pdo_name_by_std_name = (std_name, data_object_type) ->
    # console.log "call get_pdo_name_by_std_name(" + std_name + ") " + data_object_type
    for i in [0..modelFile.data_objects.length-1]
      # if true #data_object_type == "rx_sdo" || data_object_type == "tx_sdo"
      #   sameName = modelFile.data_objects[i].std_name == std_name ? 1 : 0
      #   sameType = modelFile.data_objects[i].type == data_object_type ? 1 : 0
      #   console.log "SDO  " + modelFile.data_objects[i].std_name + " / " + std_name + "  -  " + modelFile.data_objects[i].type + " / " + data_object_type + "     " + sameName + "  -  " + sameType + "  -  " + modelFile.data_objects[i].std_name.length + " / " + std_name.length
      if modelFile.data_objects[i].std_name == std_name && modelFile.data_objects[i].type == data_object_type
        # console.log "return " + modelFile.data_objects[i].name + " " + modelFile.data_objects[i].type + " " + data_object_type
        return modelFile.data_objects[i].name
    return 'XXXXX'

  get_pdo_domain_by_std_name = (std_name, data_object_type) ->
    # console.log "call get_pdo_domain_by_std_name(" + std_name + ")"
    for i in [0..modelFile.data_objects.length-1]
      if modelFile.data_objects[i].std_name == std_name && modelFile.data_objects[i].type == data_object_type
        # console.log "return " + modelFile.data_objects[i].name + " " + modelFile.data_objects[i].type + " " + data_object_type
        return modelFile.data_objects[i].domain
    return '-1'


  display_sdos = (sdo, module_id) ->
    # console.log "display_sdos()"
    j                        = 0
    k                        = 0
    data_object_product_name = ""
    buffer                   = ""
    data_type                = sdo['Type']
    #for(j=0;j<dataTypes[module_id].length;j++){
    for j in [0..dataTypes[module_id].length-1]
      if data_type.toString().replace(/\r?\n$/, '') == dataTypes[module_id][j]['Name'].toString().replace(/\r?\n$/, '')
        #for(k=0;k<100;k++){
        for k in [0..100-1]
          if dataTypes[module_id][j]['SubItem'] != undefined && dataTypes[module_id][j]['SubItem'][k] != undefined
            if dataTypes[module_id][j]['SubItem'][k]['Flags'][0]['Access'].toString().replace(/\r?\n$/, '') != 'ro'
              if product_name[module_id] == 'm1sa'
                data_object_product_name = 'sa'
              else
                data_object_product_name = product_name[module_id]
              std_name = String(dataTypes[module_id][j]['SubItem'][k]['Name'])
              buffer += '\t\t\t\t{ name: ' + ('"' + get_pdo_name_by_std_name(std_name, "rx_sdo") + '" ').padEnd(25,' ')
              buffer += ', type: "rx_sdo",  label: ' + ('"' + dataTypes[module_id][j]['SubItem'][k]['Name'] + '"').padEnd(35,' ') + ',  std_name: ' + ('"' + std_name + '"').padEnd(35,' ') + ', module: "' + modelFile.slaves[module_id].name + '", domain: ' + get_pdo_domain_by_std_name(std_name, "rx_sdo") + ' }\n'

            if dataTypes[module_id][j]['SubItem'][k]['Flags'][0]['Access'].toString().replace(/\r?\n$/, '') != 'wo'
              if product_name[module_id] == 'm1sa'
                data_object_product_name = 'sa'
              else
                data_object_product_name = product_name[module_id]
              std_name = String(dataTypes[module_id][j]['SubItem'][k]['Name'])
              buffer += '\t\t\t\t{ name: ' + ('"' + get_pdo_name_by_std_name(std_name, "tx_sdo") + '" ').padEnd(25,' ')
              buffer += ', type: "tx_sdo",  label: ' + ('"' + dataTypes[module_id][j]['SubItem'][k]['Name'] + '"').padEnd(35,' ') + ',  std_name: ' + ('"' + std_name + '"').padEnd(35,' ') + ', module: "' + modelFile.slaves[module_id].name + '", domain: ' + get_pdo_domain_by_std_name(std_name, "tx_sdo") + ' }\n'

    return buffer


  generate = (outputFileName, vendor_id, action) ->
    i=0
    console.log "ici 1\n"
    outputFileContent  = '# Autogenerated file by entering the following command line:   ' + process.argv.join(' ') + '\n'
    outputFileContent += 'module.exports =\n'
    outputFileContent += '\n'

    # masters
    outputFileContent += '\t\tmaster: [\n'
    outputFileContent += '\t\t\t\t{id: 0, rate: ' + modelFile.masters[0].rate + ' }\n'
    outputFileContent += '\t\t]\n'
    outputFileContent += '\n'

    # domains
    outputFileContent += '\t\tdomains: [\n'
    for i in [0..modelFile.domains.length-1]
      outputFileContent += '\t\t\t\t{ id: ' + i + ', master: 0, rate_factor: ' + modelFile.domains[i].rate + ' }\n'
    outputFileContent += '\t\t]\n'
    outputFileContent += '\n'

    # modules
    outputFileContent += '\t\tmodules: [\n'
    outputFileContent += '\t\t\t\t# 1) Copy the PDO mapping names you need from the comment to the pdo_mapping array. If you keep the default mapping, keep the array empty. \n\t\t\t\t# 2) Make sure you do not select two incompatible PDO mappings.\n'
    for i in [0..modelFile.slaves.length-1]
      # module_name[i-3] = 'module_' + String(i-3)
      outputFileContent += '\t\t\t\t{ name: "' + (modelFile.slaves[i].name + '"').padEnd(12,' ') + ',  position: ' + modelFile.slaves[i].position + ',  alias: 0,  type: "' + modelFile.slaves[i].type + '",  master_id: 0,  pdo_mapping: [ ] }\t\t#'
      if rx_pdos[i] != undefined
        # for(k=0; k< rx_pdos[i].length; k++)
        for k in [0..rx_pdos[i].length-1]
          outputFileContent += '"' + rx_pdos[i][k]['Name'] + '", '
      if tx_pdos[i] != undefined
        # for(k=0; k< tx_pdos[i].length; k++)
        for k in [0..tx_pdos[i].length-1]
          outputFileContent += '"' + tx_pdos[i][k]['Name'] + '", '
      outputFileContent += '\n'
    outputFileContent += '\t\t]\n'
    outputFileContent += '\n'






    # data_objects
    outputFileContent += '\t\tdata_objects: [\n'
    outputFileContent += '\t\t\t\t# 1) Delete all the data objects you do not need. \n\t\t\t\t# 2) Assign a name, a label and a type ("pdo" or "sdo") to each data object.\n'
    #for(i=3;i<product_name.length;i++){
    for i in [0..product_name.length-1]
      outputFileContent += '\n\t\t\t\t##### ' + product_name[i] + ' data objects at position ' + (i).toString() + ' #####\n'
      if rx_pdos[i] != undefined
        #for(k=0; k< rx_pdos[i].length; k++){
        for k in [0..rx_pdos[i].length-1]
          outputFileContent += '\t\t\t\t# RX :  ' + rx_pdos[i][k]['Name'] + ' (' + rx_pdos[i][k]['Index'].toString().replace('#', '0') + ')\n'
          #for(j=0;j<rx_pdos[i][k]['Entry'].length;j++){
          for j in [0..rx_pdos[i][k]['Entry'].length-1]
            if rx_pdos[i][k]['Entry'][j]['Name'] != undefined
              console.log "rx_pdos[i][k]['Entry'][j]['Name']" + rx_pdos[i][k]['Entry'][j]['Name'] + '\n'
            if rx_pdos[i][k]['Entry'][j]['Name'] != undefined && rx_pdos[i][k]['Entry'][j]['Index'] != undefined && rx_pdos[i][k]['Entry'][j]['SubIndex'] != undefined && rx_pdos[i][k]['Entry'][j]['BitLen'] != undefined
              std_name = rx_pdos[i][k]['Name'] + ' : ' + rx_pdos[i][k]['Entry'][j]['Name']
              outputFileContent += '\t\t\t\t{ name: ' + ('"' + get_pdo_name_by_std_name(std_name, "rx_pdo") + '"').padEnd(25,' ') + ', type: "rx_pdo",  label: "' + (std_name + '"').toString().padEnd(45,' ') + ',  std_name: "' + (std_name + '",').toString().padEnd(45,' ') + ' module: "' + modelFile.slaves[i].name + '", domain: ' + get_pdo_domain_by_std_name(std_name, "rx_pdo") + ' }\n'
      if tx_pdos[i] != undefined
        #for(k=0; k< tx_pdos[i].length; k++){
        for k in [0..tx_pdos[i].length-1]
          outputFileContent += '\t\t\t\t# TX :  ' + tx_pdos[i][k]['Name'] + ' (' + tx_pdos[i][k]['Index'].toString().replace('#', '0') + ')\n'
          #for(j=0;j<tx_pdos[i][k]['Entry'].length;j++){
          for j in [0..tx_pdos[i][k]['Entry'].length-1]
            if tx_pdos[i][k]['Entry'][j]['Name'] != undefined && tx_pdos[i][k]['Entry'][j]['Index'] != undefined && tx_pdos[i][k]['Entry'][j]['SubIndex'] != undefined && tx_pdos[i][k]['Entry'][j]['BitLen'] != undefined
              std_name = tx_pdos[i][k]['Name'] + ' : ' + tx_pdos[i][k]['Entry'][j]['Name']
              outputFileContent += '\t\t\t\t{ name: ' + ('"' + get_pdo_name_by_std_name(std_name, "tx_pdo") + '"').padEnd(25,' ') + ', type: "tx_pdo",  label: "' + (std_name + '"').toString().padEnd(45,' ') + ',  std_name: "' + (std_name + '",').toString().padEnd(45,' ') + ' module: "' + modelFile.slaves[i].name + '", domain: ' + get_pdo_domain_by_std_name(std_name, "tx_pdo") + ' }\n'

      # SDOs
      if(objects[i] != undefined)
        outputFileContent += '\n\t\t\t\t# SDOs\n'
        #for(j=0;j<objects[i].length;j++){
        for j in [0..objects[i].length-1]
          outputFileContent += display_sdos(objects[i][j], i)

    outputFileContent += '\t\t]\n'
    outputFileContent += '\n'

    # catalog
    catalogFileContent = '# Autogenerated file by entering the following command line:   ' + process.argv.join(' ') + '\n'
    catalogFileContent += 'module.exports =\n'
    catalogFileContent += '\n'
    catalogFileContent += '\t\tcatalog: [\n'
    #for(i=3;i<product_name.length;i++){
    for i in [0..product_name.length-1]
      catalogFileContent += '\t\t\trequire \'/home/pkurkdjian/work/etc/conf/hdk_dcs/hdk_hw1_adapter_catalog/' + product_name[i] + '_conf.coffee\'   # Slave ' + String(i) + '\n'
      catalogFileModule  = 'module.exports =\n\n'
      catalogFileModule += '\t\t\t\t{\t#slave '.concat(i) + '\n'
      catalogFileModule += '\t\t\t\t\t\tproduct_name: "' + product_name[i] + '"\n'
      catalogFileModule += '\t\t\t\t\t\tvendor_id:    ' + vendor_id + '\n'
      catalogFileModule += '\t\t\t\t\t\tproduct_code: '  + product_code[i].replace('#', '0') + '\n'
      catalogFileModule += '\t\t\t\t\t\trevision_id:  '  + revision_id[i].replace('#', '0') + '\n'
      catalogFileModule += '\t\t\t\t\t\tpdos: [\n'
      # console.log 'a ' + catalogFileModule + ' b ' + product_name[i] + ' c '
      #for(k=0; k<100; k++){
      for k in [0..100-1]
        if rx_pdos[i] != undefined && rx_pdos[i][k] != undefined && rx_pdos[i][k]['Index'] != undefined
          if rx_pdos[i][k]['$']['Sm'] != undefined
              sync_manager = rx_pdos[i][k]['$']['Sm']
          catalogFileModule += '\t\t\t\t\t\t\t\t{\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tmapping_name:  "' + rx_pdos[i][k]['Name'] + '",\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tdirection:     "RX",  # From master to slave\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tmapping_index: ' + (rx_pdos[i][k]['Index']).toString().replace('#', '0') + ',\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tsync_manager:  ' + sync_manager + ',\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tpdo_list:      [\n'
          #for(j=0;j<100;j++){
          for j in [0..100-1]
            if rx_pdos[i][k]['Entry'] != undefined && rx_pdos[i][k]['Entry'][j] != undefined
              #console.log "i k j " + i + " " + k + " " + j
              if rx_pdos[i][k]['Entry'][j]['Name'] != undefined && rx_pdos[i][k]['Entry'][j]['Index'] != undefined && rx_pdos[i][k]['Entry'][j]['BitLen'] != undefined
                index     = rx_pdos[i][k]['Entry'][j]['Index'].toString()
                if index != '#x0'
                  name    = rx_pdos[i][k]['Name'] + ' : ' + rx_pdos[i][k]['Entry'][j]['Name'].toString()
                else
                  name    = "*** gap ***"
                if rx_pdos[i][k]['Entry'][j]['SubIndex'] != undefined
                    sub_index = rx_pdos[i][k]['Entry'][j]['SubIndex'].toString(16).replace(/\D/g,'')
                else
                    sub_index = "0"
                bit_length       = rx_pdos[i][k]['Entry'][j]['BitLen']
                catalogFileModule += '\t\t\t\t\t\t\t\t\t\t\t\t{ name: "' + (name + '",').padEnd(35,' ') + ' index: ' + index.replace('#', '0')
                catalogFileModule += ', sub_index: ' + sub_index.replace('#', '0') + ', bit: 0, bit_length: ' + bit_length + ' }\n'

          catalogFileModule += '\t\t\t\t\t\t\t\t\t]\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t}\n'

      #for(k=0; k<100; k++){
      for k in [0..100-1]
        if tx_pdos[i] != undefined && tx_pdos[i][k] != undefined && tx_pdos[i][k]['Index'] != undefined
          if tx_pdos[i][k]['$']['Sm'] != undefined
            sync_manager = tx_pdos[i][k]['$']['Sm']
          catalogFileModule += '\t\t\t\t\t\t\t\t{\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tmapping_name:  "' + tx_pdos[i][k]['Name'] + '",\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tdirection:     "TX",  # From slave to master\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tmapping_index: ' + (tx_pdos[i][k]['Index']).toString().replace('#', '0') + ',\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tsync_manager:  ' + sync_manager + ',\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t\t\tpdo_list:      [\n'
          #for(j=0;j<100;j++){
          for j in [0..100-1]
            if tx_pdos[i][k]['Entry'] != undefined && tx_pdos[i][k]['Entry'][j] != undefined
              if tx_pdos[i][k]['Entry'][j]['Name'] != undefined && tx_pdos[i][k]['Entry'][j]['Index'] != undefined && tx_pdos[i][k]['Entry'][j]['BitLen'] != undefined
                index     = tx_pdos[i][k]['Entry'][j]['Index'].toString()
                if(index != '#x0')
                  name    = tx_pdos[i][k]['Name'] + ' : ' + tx_pdos[i][k]['Entry'][j]['Name'].toString()
                else
                  name    = "*** gap ***"
                if tx_pdos[i][k]['Entry'][j]['SubIndex'] != undefined
                    sub_index = tx_pdos[i][k]['Entry'][j]['SubIndex'].toString(16).replace(/\D/g,'')
                else
                    sub_index = "0"
                bit_length       = tx_pdos[i][k]['Entry'][j]['BitLen']
                catalogFileModule += '\t\t\t\t\t\t\t\t\t\t\t\t{ name: "' + (name + '",').padEnd(35,' ') + ' index: ' + index.replace('#', '0')
                catalogFileModule += ', sub_index: ' + sub_index.replace('#', '0') + ', bit: 0, bit_length: ' + bit_length + ' }\n'

          catalogFileModule += '\t\t\t\t\t\t\t\t\t]\n'
          catalogFileModule += '\t\t\t\t\t\t\t\t}\n'

      catalogFileModule += '\t\t\t\t\t\t]\n'

      if objects[i] != undefined
        catalogFileModule += '\t\t\t\t\t\tsdos: [\n'
        #for(j=0;j<objects[i].length;j++){
        for j in [0..objects[i].length-1]
          catalogFileModule += display_objects_catalog(objects[i][j], i)
        catalogFileModule += '\t\t\t\t\t\t]\n'

      catalogFileModule += '\t\t\t\t}\n'
      # console.log 'y ' + catalogFileModule + 'z'
      if action == 'catalog' or action == 'all'
        fs.writeFile 'ethercat_config/catalog_config/'+product_name[i]+'_conf.coffee', catalogFileModule, (err) ->
          if(err)
            console.log err
    catalogFileContent += '\t\t]\n'

    if action == 'fieldbus' or action == 'all'
      console.log "ici 9\n"
      fs.writeFile 'ethercat_config/fieldbus_conf.coffee', outputFileContent, (err) ->
        if(err)
          console.log err
        else
          console.log 'ethercat_config/fieldbus_conf.coffee created'

    if action == 'catalog' or action == 'all'
      fs.writeFile 'ethercat_config/catalog_conf.coffee', catalogFileContent, (err) ->
        if(err)
          console.log err
      # for i in [3..product_name.length-1]
        # catalogFileModule[i] = "abc"
        # console.log catalogFileModule[i]
        # fs.writeFile 'ethercat_config/catalog_config/'+product_name[i]+'_bis.coffee', catalogFileModule[i], (err) ->
        #   if(err)
        #     console.log err

  xmlParse = (xmlInputFileName) ->
    xmlInputFileRepository   = 'eni_files/'
    xmlInputFilePath         = xmlInputFileRepository + xmlInputFileName
    xmlInputFileContent      = fs.readFileSync xmlInputFilePath, 'utf8'
    jsonOutputFileRepository = 'module_files/'
    jsonOutputFileContent    = ''

    xml2js.parseString xmlInputFileContent, (err, content) ->
      jsonOutputFileContent = content

    for device, i in jsonOutputFileContent.EtherCATInfo['Descriptions'][0]['Devices'][0]['Device']
      if device.Type != undefined && device.Type[0] != undefined && device.Type[0]._ != undefined
        jsonOutputFileName   = device.Type[0]._.split(" ")[0]
        if RevisionNo != undefined
          jsonOutputFileName   += '-' + RevisionNo.toString().replace(/#|x/g, '')
        jsonOutputFileName   += '.coffee'
        RevisionNo = device.Type[0].$.RevisionNo
        console.dir 'creating ' + jsonOutputFileRepository + jsonOutputFileName
        fs.writeFile jsonOutputFileRepository + jsonOutputFileName, JSON.stringify(device, null, 2), (err) ->
          if err
            console.log err



  constructor: ->
    if process.argv[2] == 'parsing'
      console.log(process.argv[2])
      xmlInputFileName = process.argv[3]
      xmlParse(xmlInputFileName)

    else if(process.argv[2] == 'catalog' or process.argv[2] == 'fieldbus' or process.argv[2] == 'all')
      console.log('generation')

      modelFilePath = process.argv[3]
      modelFile = require(modelFilePath)

      argc = process.argv.length
      for i in [0..modelFile.slaves.length-1]
        deviceContent   = JSON.parse(fs.readFileSync('module_files/' + modelFile.slaves[i].type + '.coffee', 'utf8'))
        console.log("Reading " + modelFile.slaves[i].type)
        product_name[i] = deviceContent['Type'][0]['_']
        product_code[i] = deviceContent['Type'][0]['$']['ProductCode']
        revision_id[i]  = deviceContent['Type'][0]['$']['RevisionNo']
        rx_pdos[i]      = deviceContent['RxPdo']
        tx_pdos[i]      = deviceContent['TxPdo']
        console.log(product_name[i] + " " + product_code[i] + " " + revision_id[i] + " " + rx_pdos[i] + " " + tx_pdos[i])
        if deviceContent['Profile'] != undefined && deviceContent['Profile'][0]['Dictionary'] != undefined && deviceContent['Profile'][0]['Dictionary'][0]['DataTypes'] != undefined
            dataTypes[i]    = deviceContent['Profile'][0]['Dictionary'][0]['DataTypes'][0]['DataType']
            objects[i]      = deviceContent['Profile'][0]['Dictionary'][0]['Objects'][0]['Object']
      generate('ethercat_config/ethercat_config.coffee', '0x2', process.argv[2])


app = new EthercatApp
