module Silverpop

  class Engage < Silverpop::Core

    API_POST_URL  = 'https://api3.silverpop.com/XMLAPI'
    FTP_POST_URL  = 'transfer3.silverpop.com'
    USERNAME      = 'username'
    PASSWORD      = 'password'

    TMP_WORK_PATH = "#{RAILS_ROOT}/tmp/"

    def initialize()
      super API_POST_URL
      @session_id, @session_encoding, @response_xml = nil, nil, nil
    end

    ###
    #   QUERY AND SERVER RESPONSE
    ###
    def query(xml)
      se = @session_encoding.nil? ? '' : @session_encoding
      @response_xml = super(xml, se)

      log_error unless success?

      @response_xml
    end

    def success?
      return false if @response_xml.blank?

      doc = Hpricot::XML(@response_xml)
      doc.at('SUCCESS').innerHTML.downcase == 'true'
    end

    def error_message
      return false if success?

      doc = Hpricot::XML(@response_xml)
      strip_cdata( doc.at('FaultString').innerHTML )
    end

    ###
    #   SESSION MANAGEMENT
    ###
    def logged_in?
      @session_id.nil? && @session_encoding.nil?
    end

    def login
      @session_id, @session_encoding = nil, nil

      doc = Hpricot::XML( query( xml_login( USERNAME, PASSWORD ) ) )
      if doc.at('SUCCESS').innerHTML.downcase == 'true'
        @session_id       = doc.at('SESSIONID').innerHTML
        @session_encoding = doc.at('SESSION_ENCODING').innerHTML
      end

      success?
    end

    def logout
      return true unless logged_in?

      response_xml = query( xml_logout )
      success?
    end

    ###
    #   JOB MANAGEMENT
    ###
    def get_job_status(job_id)
      response_xml = query( xml_get_job_status(job_id) )
    end

    ###
    #   LIST MANAGEMENT
    ###
    def get_lists(visibility, list_type)
      # VISIBILITY 
      # Required. Defines the visibility of the lists to return.
      # * 0 – Private
      # * 1 – Shared

      # LIST_TYPE
      # Defines the type of lists to return.
      # * 0 – Regular Lists
      # * 1 – Queries
      # * 2 – Both Regular Lists and Queries
      # * 5 – Test Lists
      # * 6 – Seed Lists
      # * 13 – Suppression Lists
      response_xml = query( xml_get_lists(visibility, list_type) )
    end

    def calculate_query(query_id, email = nil)
      response_xml = query( xml_calculate_query(query_id, email) )
    end

    def import_list(map_file_path, source_file_path)
      Net::FTP.open(FTP_POST_URL) do |ftp|
        ftp.passive = true  # IMPORTANT! SILVERPOP NEEDS THIS OR IT ACTS WEIRD.
        ftp.login(USERNAME, PASSWORD)
        ftp.chdir('upload')
        ftp.puttextfile(map_file_path)
        ftp.puttextfile(source_file_path)
      end

      map_file_ftp_path = File.basename(map_file_path)
      source_file_ftp_path = File.basename(source_file_path)

      response_xml = query xml_import_list(
                              File.basename(map_file_path),
                              File.basename(source_file_path) )
    end
    
    def create_map_file (file_path, list_info, columns, mappings)
      # SAMPLE_PARAMS:
      # list_info = { :action       => 'ADD_AND_UPDATE',
      #               :list_id      => 123456,
      #               :file_type    => 0,
      #               :has_headers  => true }
      # columns   = [ { :name=>'EMAIL', :type=>9, :is_required=>true, :key_column=>true },
      #               { :name=>'FIRST_NAME', :type=>0, :is_required=>false, :key_column=>false },
      #               { :name=>'LAST_NAME', :type=>0, :is_required=>false, :key_column=>false } ]
      # mappings  = [ { :index=>1, :name=>'EMAIL', :include=>true },
      #               { :index=>2, :name=>'FIRST_NAME', :include=>true },
      #               { :index=>3, :name=>'LAST_NAME', :include=>true } ]

      File.open(file_path, 'w') do |file|
        file.puts xml_map_file(list_info, columns, mappings)
      end

      file_path
    end

    ###
    #   RECIPIENT MANAGEMENT
    ###
    def add_recipient(list_id, email, extra_columns=[], created_from=1)
      # CREATED_FROM
      # Value indicating the way in which you are adding the selected recipient
      # to the system. Values include:
      # * 0 – Imported from a list
      # * 1 – Added manually
      # * 2 – Opted in
      # * 3 – Created from tracking list
      response_xml =  query(xml_add_recipient(
                        list_id, email, extra_columns, created_from) )
    end

    def update_recipient(list_id, old_email, new_email=nil, extra_columns=[], created_from=1)
      # CREATED_FROM
      # Value indicating the way in which you are adding the selected recipient
      # to the system. Values include:
      # * 0 – Imported from a list
      # * 1 – Added manually
      # * 2 – Opted in
      # * 3 – Created from tracking list
      new_email = old_email if new_email.nil?
      response_xml =  query(xml_update_recipient(
                        list_id, old_email, new_email, extra_columns, created_from) )
    end

    def remove_recipient(list_id, email)
      response_xml = query( xml_remove_recipient(list_id, email) )
    end

    def double_opt_in_recipient(list_id, email, extra_columns=[])
      response_xml = query xml_double_opt_in_recipient(list_id, email, extra_columns)
    end

    def opt_out_recipient(list_id, email)
      response_xml = query xml_opt_out_recipient(list_id, email)
    end

  ###
  #   API XML TEMPLATES
  ###
  protected

    def log_error
      logger.debug '*** Silverpop::Engage Error: ' + error_message
    end

    def xml_login(username, password)
      ( '<Envelope><Body>'+
          '<Login>'+
            '<USERNAME>%s</USERNAME>'+
            '<PASSWORD>%s</PASSWORD>'+
          '</Login>'+
        '</Body></Envelope>'
      ) % [username, password]
    end

    def xml_logout
      '<Envelope><Body><Logout/></Body></Envelope>'
    end

    def xml_get_job_status(job_id)
      ( '<Envelope><Body>'+
          '<GetJobStatus>'+
            '<JOB_ID>%s</JOB_ID>'+
          '</GetJobStatus>'+
        '</Body></Envelope>'
      ) % [job_id]
    end

    def xml_get_lists(visibility, list_type)
      (  '<Envelope><Body>'+
          '<GetLists>'+
            '<VISIBILITY>%s</VISIBILITY>'+
            '<LIST_TYPE>%s</LIST_TYPE>'+
          '</GetLists>' +
        '</Body></Envelope>'
      ) % [visibility.to_s, list_type.to_s]
    end

    def xml_calculate_query(query_id, email)
      xml = ( '<Envelope><Body>'+
                '<CalculateQuery>'+
                  '<QUERY_ID>%s</QUERY_ID>'+
                '</CalculateQuery>'+
              '</Body></Envelope>'
            ) % [query_id]
      unless email.nil?
        doc = Hpricot::XML(xml)
        (doc/:CalculateQuery).append('<EMAIL>%s/EMAIL>' % email)
        xml = doc.to_s
      end
      xml
    end

    def xml_import_list(map_file, source_file)
      ( '<Envelope><Body>'+
          '<ImportList>'+
            '<MAP_FILE>%s</MAP_FILE>'+
            '<SOURCE_FILE>%s</SOURCE_FILE>'+
          '</ImportList>'+
        '</Body></Envelope>'
      ) % [map_file, source_file]
    end
    
    def xml_map_file(list_info, columns, mappings)
      return false unless (columns.size > 0 && mappings.size > 0)

      xml = '<LIST_IMPORT>'+
              '<LIST_INFO></LIST_INFO>'+
              '<COLUMNS></COLUMNS>'+
              '<MAPPING></MAPPING>'+
            '</LIST_IMPORT>'

      doc = Hpricot::XML(xml)
      doc.at('LIST_INFO').innerHTML = xml_map_file_list_info(list_info)

      str = ''
      columns.each { |c| str += xml_map_file_column(c) }
      doc.at('COLUMNS').innerHTML = str

      str = ''
      mappings.each { |m| str += xml_map_file_mapping_column(m) }
      doc.at('MAPPING').innerHTML = str

      doc.to_s
    end

    def xml_map_file_list_info(list_info)
      # ACTION:
      #   Defines the type of list import you are performing. The following is a
      #   list of valid values and how interprets them:
      #   • CREATE
      #     – create a new list. If the list already exists, stop the import.
      #   • ADD_ONLY
      #     – only add new recipients to the list. Ignore existing recipients
      #       when found in the source file.
      #   • UPDATE_ONLY
      #     – only update the existing recipients in the list. Ignore recipients
      #       who exist in the source file but not in the list.
      #   • ADD_AND_UPDATE
      #     – process all recipients in the source file. If they already exist
      #       in the list, update their values. If they do not exist, create a
      #        new row in the list for the recipient.
      #   • OPT_OUT
      #     – opt out any recipient in the source file who is already in the list.
      #       Ignore recipients who exist in the source file but not the list.

      # FILE_TYPE:
      #   Defines the formatting of the source file. Supported values are:
      #   0 – CSV file, 1 – Tab-separated file, 2 – Pipe-separated file
      
      # HASHEADERS
      #   The HASHEADERS element is set to true if the first line in the source
      #   file contains column definitions. The List Import API does not use
      #   these headers, so if you have them, this element must be set to true
      #   so it can skip the first line.

      ( '<ACTION>%s</ACTION>'+
        '<LIST_ID>%s</LIST_ID>'+
        '<FILE_TYPE>%s</FILE_TYPE>'+
        '<HASHEADERS>%s</HASHEADERS>'
      ) % [ list_info[:action],
            list_info[:list_id],
            list_info[:file_type],
            list_info[:has_headers] ]
    end

    def xml_map_file_column(column)
      # TYPE
      #   Defines what type of column to create. The following is a list of
      #   valid values:
      #     0 – Text column
      #     1 – YES/No column
      #     2 – Numeric column
      #     3 – Date column
      #     4 – Time column
      #     5 – Country column
      #     6 – Select one
      #     8 – Segmenting
      #     9 – System (used for defining EMAIL field only)

      # KEY_COLUMN
      #   Added to field definition and defines a field as a unique key for the
      #   list when set to True. You can define more than one unique field for
      #   each list.

      ( '<COLUMN>'+
          '<NAME>%s</NAME>'+
          '<TYPE>%s</TYPE>'+
          '<IS_REQUIRED>%s</IS_REQUIRED>'+
          '<KEY_COLUMN>%s</KEY_COLUMN>'+
        '</COLUMN>'
      ) % [ column[:name].upcase,
            column[:type],
            column[:is_required],
            column[:key_column] ]
    end

    def xml_map_file_mapping_column(column)
      column = { :include => true }.merge(column)
      
      ( '<COLUMN>'+
          '<INDEX>%s</INDEX>'+
          '<NAME>%s</NAME>'+
          '<INCLUDE>true</INCLUDE>'+
        '</COLUMN>'
      ) % [ column[:index],
            column[:name].upcase,
            column[:include] ]
    end

    def xml_add_recipient(list_id, email, extra_columns, created_from)
      xml = ( '<Envelope><Body>'+
                '<AddRecipient>'+
                  '<LIST_ID>%s</LIST_ID>'+
                  '<CREATED_FROM>%s</CREATED_FROM>'+
                  '<UPDATE_IF_FOUND>true</UPDATE_IF_FOUND>'+
                  '<COLUMN>'+
                    '<NAME>EMAIL</NAME>'+
                    '<VALUE>%s</VALUE>'+
                  '</COLUMN>'+
                '</AddRecipient>'+
              '</Body></Envelope>'
      ) % [list_id, created_from, email]

      doc = Hpricot::XML(xml)
      if extra_columns.size > 0
        extra_columns.each do |c|
          (doc/:AddRecipient).append xml_add_recipient_column(c[:name], c[:value])
        end
      end

      doc.to_s
    end

    def xml_update_recipient(list_id, old_email, new_email, extra_columns, created_from)
      xml = ( '<Envelope><Body>'+
                '<UpdateRecipient>'+
                  '<LIST_ID>%s</LIST_ID>'+
                  '<CREATED_FROM>%s</CREATED_FROM>'+
                  '<OLD_EMAIL>%s</OLD_EMAIL>'+
                  '<COLUMN>'+
                    '<NAME>EMAIL</NAME>'+
                    '<VALUE>%s</VALUE>'+
                  '</COLUMN>'+
                '</UpdateRecipient>'+
              '</Body></Envelope>'
      ) % [list_id, created_from, old_email, new_email]

      doc = Hpricot::XML(xml)
      if extra_columns.size > 0
        extra_columns.each do |c|
          (doc/:UpdateRecipient).append xml_add_recipient_column(c[:name], c[:value])
        end
      end

      doc.to_s
    end

    def xml_add_recipient_column(name, value)
      ( '<COLUMN>'+
          '<NAME>%s</NAME>'+
          '<VALUE>%s</VALUE>'+
        '</COLUMN>'
      ) % [name, value]
    end

    def xml_remove_recipient(list_id, email)
      ( '<Envelope><Body>'+
          '<RemoveRecipient>'+
            '<LIST_ID>%s</LIST_ID>'+
            '<EMAIL>%s</EMAIL>'+
          '</RemoveRecipient>'+
        '</Body></Envelope>'
      ) % [list_id, email]
    end

    def xml_double_opt_in_recipient(list_id, email, extra_columns)
      ( '<Envelope><Body>'+
          '<DoubleOptInRecipient>'+
            '<LIST_ID>%s</LIST_ID>'+
              '<COLUMN>'+
                '<NAME>EMAIL</NAME>'+
                '<VALUE>%s</VALUE>'+
              '</COLUMN>'+
          '</DoubleOptInRecipient>'+
        '</Body></Envelope>'
      ) % [list_id, email]
    end

    def xml_opt_out_recipient(list_id, email)
      ( '<Envelope><Body>'+
          '<OptOutRecipient>'+
            '<LIST_ID>%s</LIST_ID>'+
            '<EMAIL>%s</EMAIL>'+
          '</OptOutRecipient>'+
        '</Body></Envelope>'
      ) % [list_id, email]
    end

  end

end