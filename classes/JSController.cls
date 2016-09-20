public with sharing class JSController {

    private ToolingApi tooling = new ToolingApi();

    private ToolingAPI.MetadataContainer classContainer = new ToolingAPI.MetadataContainer();
    private ToolingAPI.MetadataContainer triggerContainer = new ToolingAPI.MetadataContainer();

    private List<ToolingAPI.MetadataContainer> containers;

    private transient List<ApexClass> apexClassList;
    private transient Set<ApexClass> apexClassSet = new Set<ApexClass>();
    private List<ApexTrigger> apexTriggerList;

    private List<String> classesNames = new List<String>();
    private List<String> triggersNames = new List<String>();
    private List<String> customClassNames = new List<String>{'fflib_SObjectDomain', 'fflib_SObjectSelector', 'fflib_StringBuilder', 
                                                             'ToolingAPI', 'UmlService', 'ApexClassesSelector', 'ClassMethodService',
                                                             'VisualforceParser', 'JSController', 'FakeClassForTestCoverage'};
    private List<ExceptionClassesNames__c> ecnList = ExceptionClassesNames__c.getAll().values();
   
    private static final String CONTAINER_NAME_FOR_CLASSES = 'ApexClassNavigator';
    private static final String CONTAINER_NAME_FOR_TRIGGERS = 'ApexTriggerNavigator';

    public String requestStatus { get; set; }
    public String requestMore { get; set; }

    private static final String TEST_ANNOTATION = '(?i)(@isTest)';
    private static final String TEST_ANNOTATION_BEFORE_CLASS = '(?i)(@isTest)([\\w\\s]+)(\\s){1}(class){1}(\\s){1}';

    private static final Pattern PATTERN_TEST_ANNOTATION = Pattern.compile(TEST_ANNOTATION);
    private static final Pattern PATTERN_TEST_ANNOTATION_BEFORE_CLASS = Pattern.compile(TEST_ANNOTATION_BEFORE_CLASS);
    private static Matcher testAnnotationM;
    private static Matcher testAnnotationBeforeClassM;


    private Integer currentRequest = 0; 
    private Integer i = 0;
    private Integer classesNumber; 
    private Integer triggersNumber;
    private Integer requestNumber; 

    private Id classContainerId;
    private Id triggerContainerId;

    public JSController () {
    
        for (ExceptionClassesNames__c ecn : ecnList) {
            customClassNames.add(ecn.ExceptionClassName__c);
        }
        apexClassList = [SELECT Name, Body, ApiVersion
                         FROM ApexClass 
                         WHERE NamespacePrefix = null AND Name NOT IN:customClassNames];   //

        apexClassSet.addAll(apexClassList);
        for (ApexClass ac : apexClassSet) {
            testAnnotationM = PATTERN_TEST_ANNOTATION.matcher(ac.body);
            testAnnotationBeforeClassM = PATTERN_TEST_ANNOTATION_BEFORE_CLASS.matcher(ac.body);
            while ( ( testAnnotationM.find() && (ac.ApiVersion > 27) ) || ( testAnnotationBeforeClassM.find() && (ac.ApiVersion < 28) )  ) {
                apexClassSet.remove(ac);
            }
        } 
        apexClassList.clear();
        apexClassList.addAll(apexClassSet);
        apexTriggerList = [SELECT Name 
                           FROM ApexTrigger 
                           WHERE NamespacePrefix = null]; 

        classesNumber = apexClassList.size();
        triggersNumber = apexTriggerList.size();
        requestNumber = classesNumber + triggersNumber;

        for (ApexClass ac : apexClassList){
            classesNames.add(ac.Name);
        }

        for (ApexTrigger at : apexTriggerList){
            triggersNames.add(at.Name);
        }

        containers = (List<ToolingAPI.MetadataContainer>) tooling.query('SELECT Id, Name FROM MetadataContainer').records; 
        
        if (containers != null) {
            for (ToolingAPI.MetadataContainer cl : containers) { 
                tooling.deleteSObject(ToolingAPI.SObjectType.MetadataContainer, cl.Id); 
            }
        }
         
        classContainer.name = CONTAINER_NAME_FOR_CLASSES;
        triggerContainer.name = CONTAINER_NAME_FOR_TRIGGERS;
        
        ToolingAPI.SaveResult classContainerSaveResult = new ToolingAPI.SaveResult();
        ToolingAPI.SaveResult triggerContainerSaveResult = new ToolingAPI.SaveResult();
        
        classContainerSaveResult = tooling.createSObject(classContainer);
        triggerContainerSaveResult = tooling.createSObject(triggerContainer);
        
        classContainerId = classContainerSaveResult.id;
        triggerContainerId = triggerContainerSaveResult.id;
    }

    public void doRequest () {

        if (currentRequest <= requestNumber) {
            
            for (Integer startPoint = currentRequest; (currentRequest < requestNumber)  && ((currentRequest - startPoint) < 1); currentRequest++) { 
                if (currentRequest < classesNumber) {
                    UmlService.compile(classesNames[currentRequest], classContainerId);
                } else {
                    String apexTriggerName = triggersNames[i++];
                    ApexTrigger apexTrigger = [SELECT Id, Body, Name FROM ApexTrigger WHERE Name = :apexTriggerName];
                    ToolingAPI.ApexTriggerMember apexTriggerMember = new ToolingAPI.ApexTriggerMember();
                    apexTriggerMember.Body = apexTrigger.Body;
                    apexTriggerMember.ContentEntityId = apexTrigger.id;
                    apexTriggerMember.MetadataContainerId = triggerContainerId;
                    tooling.createSObject(apexTriggerMember);
                }
            }
            requestStatus = currentRequest + ' out of ' + requestNumber + ' processed';
        }

        if (currentRequest >= requestNumber) {
            requestMore = 'false';
            ToolingAPI.ContainerAsyncRequest asyncRequestForClasses = new ToolingAPI.ContainerAsyncRequest();
            asyncRequestForClasses.metadataContainerId = classContainerId;
            ToolingAPI.ContainerAsyncRequest asyncRequestForTriggers = new ToolingAPI.ContainerAsyncRequest();
            asyncRequestForTriggers.metadataContainerId = triggerContainerId;
            asyncRequestForClasses.IsCheckOnly = true;
            asyncRequestForTriggers.IsCheckOnly = true;
            tooling.createSObject(asyncRequestForClasses);   
            tooling.createSObject(asyncRequestForTriggers);
        } else  {
            requestMore = 'true';
        }
    }
    
    public void doInsert() {
        ID jobID = System.enqueueJob(new ClassMethodService()); 
    }

    public void doFindPotentialUnusedMethods() {
        ClassMethodService.findPotentialUnusedMethods();
    }
    
    public void doFindUnusedClasses() {
        ClassMethodService.findUnusedClasses();
    }
}