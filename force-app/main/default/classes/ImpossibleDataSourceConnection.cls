global without sharing class ImpossibleDataSourceConnection extends DataSource.Connection {

    
    global ImpossibleDataSourceConnection(DataSource.ConnectionParams connectionParams) {
    }

    global ImpossibleDataSourceConnection() {
    }

    override global List<DataSource.Table> sync() 
    {
        List<DataSource.Table> tables = new List<DataSource.Table>();
        // Profiles table
        List<DataSource.Column> columns;
        columns = new List<DataSource.Column>();
        columns.add(DataSource.Column.url('DisplayUrl'));
        columns.add(DataSource.Column.text('Name', 255));
        columns.add(DataSource.Column.text('UserType', 40));
        columns.add(DataSource.Column.text('ExternalId', 255));
        for(String fieldname:getProfilePermissions())
        {
            columns.add(DataSource.Column.boolean(fieldname));
        }
        Datasource.Table t = DataSource.Table.get('ImpossibleProfiles', 'Name', columns);
        t.description = 'Mirrored profile object via Apex connector';
        t.labelSingular = 'Impossible profile';
        t.labelPlural = 'Impossible profiles';
        tables.add(t);

        // Class table
        columns = new List<Datasource.Column>();
        columns.add(DataSource.Column.url('DisplayUrl'));
        columns.add(DataSource.Column.text('Name', 255));
        columns.add(DataSource.Column.number('ApiVersion',12,6));
        columns.add(DataSource.Column.number('LengthWithoutComments',12,0));
        columns.add(DataSource.Column.text('NamespacePrefix',40));
        columns.add(DataSource.Column.lookup('CreatedById','User'));
        columns.add(DataSource.Column.lookup('LastModifiedById','User'));
        columns.add(DataSource.Column.text('ExternalId', 255));
        t = DataSource.Table.get('ImpossibleClasses', 'Name', columns);
        t.description = 'Impossible Apex Class Table';
        t.labelSingular = 'Impossible class';
        t.labelPlural = 'Impossible classes';
        tables.add(t);


        columns = new List<Datasource.Column>();
        columns.add(DataSource.Column.url('DisplayUrl'));
        columns.add(DataSource.Column.text('ExternalId', 255));
        columns.add(DataSource.Column.text('Name',255));
        columns.add(DataSource.Column.lookup('AssigneeId','User'));
        columns.add(DataSource.Column.text('PermissionSetId',255));
        columns.add(DataSource.Column.text('Description', 255));
        t = DataSource.Table.get('ImpossiblePermissionSetAssignment', 'Name', columns);
        t.description = 'Impossible Permission set assignments';
        t.labelSingular = 'Permission Set Assignment';
        t.labelPlural = 'Permission Set Assignments';
        tables.add(t);

        columns = new List<Datasource.Column>();
        columns.add(DataSource.Column.url('DisplayUrl'));
        columns.add(DataSource.Column.text('ExternalId', 255));
        columns.add(DataSource.Column.text('Name',255));
        columns.add(DataSource.Column.lookup('MemberId','User'));
        columns.add(DataSource.Column.text('GroupId', 32));
        columns.add(DataSource.Column.text('Type', 255));
        t = DataSource.Table.get('ImpossibleGroupMembers', 'Name', columns);
        t.description = 'Impossible Group member assignments';
        t.labelSingular = 'Group Member Assignment';
        t.labelPlural = 'Group Member Assignments';
        tables.add(t);


        for(Datasource.Column c: columns) system.debug(c);
        SetupColumnLabels(tables);
        return tables;
    }

    public Datasource.TableResult queryResult;

    override global DataSource.TableResult query(DataSource.QueryContext context) {
        if (context.tableSelection.columnsSelected.size() == 1 &&
            context.tableSelection.columnsSelected.get(0).aggregation ==
            DataSource.QueryAggregation.COUNT) 
        {
            List<Map<String, Object>> countResponse = new List<Map<String, Object>>();
            Map<String, Object> countRow = new Map<String, Object>();
            integer count = Database.countQuery(getCountQuery(context));
            countRow.put(context.tableSelection.columnsSelected.get(0).columnName, count);
            countResponse.add(countRow);
            return DataSource.TableResult.get(context,countResponse);
        } else 
        {
            List<SObject> rows = Database.query(getSoqlQuery(context));
            Integer totalRows = Database.countquery(getCountQuery(context));

            List<Map<String,Object>> rowsList = new List<Map<String, Object>>();
            for(SObject row: rows)
            {
                Map<String, Object> rowResults = new Map<String, Object>();
                for(Datasource.ColumnSelection c: context.tableSelection.columnsSelected) 
                {
                    Object cv = getColumnValue(context.tableSelection.tableSelected, row,c.columnName);
                    system.debug('setting ' + c.columnName + ' value ' + cv);
                    rowResults.put(c.columnName, cv);
                }
                rowsList.add(rowResults);
            }
            Datasource.TableResult queryResult = DataSource.TableResult.get(context,rowsList);
            queryResult.totalSize = totalRows;
            system.debug(queryResult);
            return queryResult;
        }
    }


    override global List<DataSource.TableResult> search(DataSource.SearchContext context) {
        return DataSource.SearchUtils.searchByName(context, this);
    }

    private List<String> getProfilePermissions()
    {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Profile.fields.getMap();
        List<String> permissions = new List<String>();
        for(String f: fields.keyset())
        {
            if(f.startsWith('permissions')) permissions.add(f);
        }
        return permissions;
    }

    private Map<String, String> mapImpossibleTableToStandardClass = 
        new Map<String,String> {'ImpossibleProfiles' => 'Profile',
                                'ImpossibleClasses' => 'ApexClass',
                                'ImpossiblePermissionSetAssignment' => 'PermissionSetAssignment',
                                'ImpossibleGroupMembers' => 'GroupMember' };

    private String getCountQuery(DataSource.QueryContext context) {
        system.debug('getCountQuery ' + context);
        String baseQuery = 'SELECT COUNT() FROM ' + mapImpossibleTableToStandardClass.get(context.tableSelection.tableSelected);
        String filter = getFilterSoqlTerm(context.tableSelection.filter);
        if (filter.length() > 0)
        baseQuery += ' WHERE ' + filter;
        system.debug('getCountQuery: ' + baseQuery);
        return baseQuery;
    }

    private String getSoqlQuery(DataSource.QueryContext context) {
        system.debug('Query context ' + context);
        Datasource.TableSelection table = context.tableSelection;
        List<Datasource.ColumnSelection> columns = table.columnsSelected;
        Set<String> fields = new Set<String>();
        for(Datasource.ColumnSelection c: columns) 
        {
            system.debug(c);
            fields.add(mapColumnName(table.tableSelected, c.columnName));
        }
        String baseQuery = 'Select ' + string.join(new List<String>(fields), ',');
        baseQuery+= ' From ' + mapImpossibleTableToStandardClass.get(table.tableSelected);
        if(context.offset!=0)
        {
            baseQuery+= ' Offset :context.query ';
        }
        String filter = getFilterSoqlTerm(context.tableSelection.filter);
        if (filter.length() > 0) baseQuery += ' WHERE ' + filter;
        String order = getOrderSoqlTerm(context.tableSelection.order);
        baseQuery += order;
        baseQuery+= ' Limit ' + String.valueOf(context.maxResults);
        system.debug('getSoqlQuery: ' + baseQuery);
        return baseQuery;
    }


    private String mapColumnName(String tablename, String apexName) {
        if(apexName==null) return null;
        if (apexName.equalsIgnoreCase('ExternalId')) return 'Id';
        if (apexName.equalsIgnoreCase('DisplayUrl')) return 'Id';
        switch on tablename {
        when 'ImpossibleClasses'
            {
            }
        when 'ImpossibleProfiles'
            {
            }
        when 'ImpossiblePermissionSetAssignment'
            {
                if(apexName.equalsIgnoreCase('Description')) return 'PermissionSet.Description';
                if(apexName.equalsIgnoreCase('Name')) return 'PermissionSet.Name';
            }
        when 'ImpossibleGroupMembers'
            {
                if(apexName.equalsIgnoreCase('Description')) return 'PermissionSet.Description';
                if(apexName.equalsIgnoreCase('Name')) return 'Group.Name';
                if(apexName.equalsIgnoreCase('Type')) return 'Group.Type';
                if(apexName.equalsIgnoreCase('MemberId')) return 'UserOrGroupId';
            }
        }
        return apexName;
    }

    private Object getColumnValue(String tablename, SObject obj, String fieldName)
    {
        if(fieldName==null) return null;
        if (fieldName.equalsIgnoreCase('ExternalId')) 
        {
            return (string)obj.get('Id');
        }
        if (fieldName.equalsIgnoreCase('DisplayUrl')) 
        {
            return Url.getSalesforceBaseUrl().toExternalForm() +'/' + obj.get('Id');
        }
        switch on tablename {
            when 'ImpossibleClasses' {
                if(fieldName.equalsIgnoreCase('Creator')) return (String)obj.get('CreatedById');
            }
            when 'ImpossiblePermissionSetAssignment'
            {
                if(fieldName.equalsIgnoreCase('Description')) return (string)getFieldValue(obj, 'PermissionSet.Description');
                if(fieldName.equalsIgnoreCase('Name')) return (string)getFieldValue(obj, 'PermissionSet.Name');
            }
            when 'ImpossibleGroupMembers'
            {
                if(fieldName.equalsIgnoreCase('Description')) return (string)getFieldValue(obj, 'PermissionSet.Description');
                if(fieldName.equalsIgnoreCase('Name')) return (string)getFieldValue(obj, 'Group.Name');
                if(fieldName.equalsIgnoreCase('Type')) return (string)getFieldValue(obj, 'Group.Type');
                if(fieldName.equalsIgnoreCase('MemberId')) {
                    ID resid = (ID)obj.get('UserOrGroupId');
                    if(resid.getSObjectType() == User.SObjectType ) return (string)resid;
                    return null;
                }
            }

        }
        Object resultObj =  obj.get(mapColumnName(tablename, fieldName));
        if(resultObj instanceOf ID) return (string)resultObj;
        return resultObj;
    }
    
    private Map<DataSource.FilterType, String> filterMap = new Map<DataSource.FilterType, String>{
        DataSource.FilterType.AND_ => ' AND ',
        DataSource.FilterType.CONTAINS => ' LIKE \'%{0}%\'',
        DataSource.FilterType.ENDS_WITH => ' LIKE \'%{0}\'',
        DataSource.FilterType.EQUALS => ' = ',
        DataSource.FilterType.GREATER_THAN => ' > ',
        DataSource.FilterType.GREATER_THAN_OR_EQUAL_TO => ' >= ',
        DataSource.FilterType.LESS_THAN => ' < ',
        DataSource.FilterType.LESS_THAN_OR_EQUAL_TO => ' <= ',
        DataSource.FilterType.LIKE_ => ' LIKE ',
        DataSource.FilterType.NOT_ => ' NOT ',
        DataSource.FilterType.NOT_EQUALS => ' <> ',
        DataSource.FilterType.OR_ => ' OR ',
        DataSource.FilterType.STARTS_WITH => ' LIKE \'{0}%\''
    };


    private String getFilterSoqlTerm(DataSource.Filter filter)
    {
        if(filter==null) return '';
        String result = '';
        if(filter.subfilters!=null)
        {
            if(filter.subfilters.size()==0)
            {
                return filtermap.get(filter.type) + getFilterSoqlTerm(filter.subfilters[0]);
            }
            else
            {
                result += ' ( ' + getFilterSoqlTerm(filter.subfilters[0]);
                for(Integer fidx = 1; fidx< filter.subfilters.size(); fidx++)
                {
                    result += filtermap.get(filter.type) + getFilterSoqlTerm(filter.subfilters[fidx]);
                }
                result += ' ) ';
            }
        }
        else
        {
            String filterTerm = filtermap.get(filter.type);
            if(filterTerm.contains('{0}'))
            {
                result+= mapColumnName(filter.tableName, filter.columnName) + string.format(filterTerm, new List<String>{String.valueOf(filter.columnValue)});
            }
            else 
            {
                result += mapColumnName(filter.tableName, filter.columnName) + filterTerm + wrapValue(filter.columnValue);
            }
        }
        return result;
    }

    private String getOrderSoqlTerm(List<DataSource.Order> orders)
    {
       if(orders==null || orders.size()>0) return '';
       string result = '';
       List<String> orderItems = new List<String>();
       for(DataSource.Order order: orders)
       {
           if(order==null) break;
            orderitems.add(order.columnName + ((order.direction== Datasource.OrderDirection.ASCENDING)? ' ASC ':' DESC '));
       }
       if(orderItems.size()>0) result = ' ORDER BY ' + string.join(orderItems, ',');
       return result;
    }

    private String wrapValue(Object foundValue) {
        if (foundValue instanceof String)
            return '\'' + String.valueOf(foundValue) + '\'';
        return String.valueOf(foundValue);
    }

    private void SetupColumnLabels(List<DataSource.Table> tables)
    {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

        for(DataSource.Table table: tables)
        {
            String tableName = table.name;
            String className = mapImpossibleTableToStandardClass.get(tableName);
            Schema.DescribeSObjectResult objinfo = gd.get(className).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objinfo.fields.getMap();
            for(DataSource.Column col: table.columns)
            {
                String fieldName = mapColumnName(tableName, col.name);
                if(fieldName == null || fieldName.contains('.'))
                {   // It's probably a related field - we don't dig that far
                    col.label = col.name;
                    continue;
                }
                Schema.SObjectField fieldDescriptor = fieldMap.get(fieldName);
                if(fieldDescriptor==null) continue;
                Schema.DescribeFieldResult fieldinfo = fieldDescriptor.getDescribe();
                col.label = fieldinfo.label;
                col.description = fieldinfo.getInlineHelpText();
                col.filterable = fieldinfo.filterable;
                col.sortable = fieldinfo.sortable;
            }
        }
    }

    private Object getFieldValue(SObject obj, String fieldname)
    {
        if(fieldname.contains('.'))
        {
            List<String> fieldsegments = fieldname.split('\\.');
            for(Integer p = 0; p< fieldsegments.size()-1; p++)
            {
                obj = obj.getSObject(fieldsegments[p]);
            }
            return obj.get(fieldsegments[fieldsegments.size()-1]);            
        }
        else return obj.get(fieldname);
    }

    global override List<DataSource.UpsertResult> upsertRows(DataSource.UpsertContext context) {
        List<DataSource.UpsertResult> results = new List<DataSource.UpsertResult>();
        List<Map<String, Object>> rows = context.rows;
        for(Map<String,Object> row: rows)
        {
            results.add(DataSource.UpsertResult.success(String.valueOf(row.get('ExternalId'))));
        }
        return results;
    }

}
