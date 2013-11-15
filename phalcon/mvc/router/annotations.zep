
/*
 +------------------------------------------------------------------------+
 | Phalcon Framework                                                      |
 +------------------------------------------------------------------------+
 | Copyright (c) 2011-2013 Phalcon Team (http://www.phalconphp.com)       |
 +------------------------------------------------------------------------+
 | This source file is subject to the New BSD License that is bundled     |
 | with this package in the file docs/LICENSE.txt.                        |
 |                                                                        |
 | If you did not receive a copy of the license and are unable to         |
 | obtain it through the world-wide-web, please send an email             |
 | to license@phalconphp.com so we can send you a copy immediately.       |
 +------------------------------------------------------------------------+
 | Authors: Andres Gutierrez <andres@phalconphp.com>                      |
 |          Eduar Carvajal <eduar@phalconphp.com>                         |
 +------------------------------------------------------------------------+
 */

namespace Phalcon\Mvc\Router;

/**
 * Phalcon\Mvc\Router\Annotations
 *
 * A router that reads routes annotations from classes/resources
 *
 *<code>
 * $di['router'] = function() {
 *
 *		//Use the annotations router
 *		$router = new \Phalcon\Mvc\Router\Annotations(false);
 *
 *		//This will do the same as above but only if the handled uri starts with /robots
 * 		$router->addResource('Robots', '/robots');
 *
 * 		return $router;
 *	};
 *</code>
 */
class Annotations extends Phalcon\Mvc\Router
{
	protected _handlers;

	protected _processed = false;

	protected _controllerSuffix = "Controller";

	protected _actionSuffix = "Action";

	protected _routePrefix;

	/**
	 * Adds a resource to the annotations handler
	 * A resource is a class that contains routing annotations
	 *
	 * @param string handler
	 * @param string prefix
	 * @return Phalcon\Mvc\Router\Annotations
	 */
	public function addResource(string! handler, string! prefix=null) -> <Phalcon\Mvc\Router\Annotations>
	{

		let this->_handlers[] = [prefix, handler],
			this->_processed = false;
		return this;
	}

	/**
	 * Adds a resource to the annotations handler
	 * A resource is a class that contains routing annotations
	 * The class is located in a module
	 *
	 * @param string module
	 * @param string handler
	 * @param string prefix
	 * @return Phalcon\Mvc\Router\Annotations
	 */
	public function addModuleResource(string! module, string! handler, string! prefix=null) -> <Phalcon\Mvc\Router\Annotations>
	{

		let this->_handlers[] = [prefix, handler, module],
		this->_processed = false;

		return this;
	}

	/**
	 * Produce the routing parameters from the rewrite information
	 *
	 * @param string uri
	 */
	public function handle(string! uri=null)
	{
		var realUri, annotationsService, handlers;

		if !uri {
			/**
		 	 * If 'uri' isn't passed as parameter it reads _GET['_url']
		 	 */
			let realUri = this->getRewriteUri();
		} else {
			let realUri = uri;
		}

		if this->_processed {

			let annotationsService = null;

			let handlers = this->_handlers;
			if typeof handlers == "array" {

				let controllerSuffix = this->_controllerSuffix;

				for scope in handlers {

					if typeof scope == "array" {

						/**
						 * A prefix (if any) must be in position 0
						 */
						let prefix = scope[0];

						if typeof prefix == "string" {
							if starts_with(realUri, prefix) {
								continue;
							}
						}

						if typeof annotationsService == "object" {

							let dependencyInjector = <Phalcon\DiInterface> this->_dependencyInjector;
							if typeof dependencyInjector != "object" {
								throw new Phalcon\Mvc\Router\Exception("A dependency injection container is required to access the 'annotations' service");
							}

							let annotationsService = dependencyInjector->getShared("annotations");
						}

						/**
						 * The controller must be in position 1
						 */
						let handler = scope[1];

						if memnstr(handler, "\\") {

							/**
							 * Extract the real class name from the namespaced class
							 * The lowercased class name is used as controller
							 * Extract the namespace from the namespaced class
							 */
							let controllerName = get_class_ns(handler),
								lowerControllerName = phalcon_uncamelize(controllerName),
								namespaceName = get_ns_class(handler);

						} else {
							let controllerName = handler,
								lowerControllerName = phalcon_uncamelize(controllerName),
								namespaceName = null;
						}

						let this->_routePrefix = null;

						/**
						 * Check if the scope has a module associated
						 */
						if !fetch moduleName, scope[2] {
							let moduleName = null;
						}

						let sufixed = handler . controllerSuffix;

						/**
						 * Get the annotations from the class
						 */
						let handlerAnnotations = annotationsService->get(sufixed);

						/**
						 * Process class annotations
						 */
						let classAnnotations = handlerAnnotations->getClassAnnotations();
						if typeof classAnnotations == "object" {

							/**
							 * Process class annotations
							 */
							let annotations = classAnnotations->getAnnotations();
							if typeof annotations == "array" {
								for annotation in annotations {
									this->processControllerAnnotation(controllerName, annotation);
								}
							}
						}

						/**
						 * Process method annotations
						 */
						let methodAnnotations = handlerAnnotations->getMethodsAnnotations();
						if typeof methodAnnotations == "array" {
							let lowercased = phalcon_uncamelize(handler);
							for method, collection in methodAnnotations {
								if typeof collection == "object" {
									for annotation in collection->getAnnotations() {
										this->processActionAnnotation(moduleName, namespaceName, lowerControllerName, method, annotation);
									}
								}
							}
						}

					}
				}
			}

			let this->_processed = true;
		}

		/**
		 * Call the parent handle method()
		 */
		parent::handle(realUri);
	}

	/**
	 * Checks for annotations in the controller docblock
	 *
	 * @param string handler
	 * @param Phalcon\Annotations\AdapterInterface
	 */
	public function processControllerAnnotation(string! handler, <Phalcon\Annotations\AdapterInterface> annotation)
	{
		/**
		 * @RoutePrefix add a prefix for all the routes defined in the model
		 */
		if annotation->getName() == "RoutePrefix" {
			let this->_routePrefix = annotation->getArgument(0);
		}
	}

	/**
	 * Checks for annotations in the public methods of the controller
	 *
	 * @param string module
	 * @param string namespaceName
	 * @param string controller
	 * @param string action
	 * @param Phalcon\Annotations\Annotation annotation
	 */
	public function processActionAnnotation(string! module, string! namespaceName, string! controller, string! action,
		<Phalcon\Annotations\Annotation> annotation)
	{

		let isRoute = false, methods = null;

		let name = annotation->getName();

		/**
		 * Find if the route is for adding routes
		 */
		if name == "Route" {
			let isRoute = true;
		} else {
			if name == "Get" {
				let isRoute = true, methods = "GET";
			} else {
				if name == "Post" {
					let isRoute = true, methods = "POST";
				} else {
					if name == "Put" {
						let isRoute = true, methods = "PUT";
					} else {
						if name == "Options" {
							let isRoute = true, methods = "OPTIONS";
						}
					}
				}
			}
		}

		if isRoute === true {

			let actionName = strtolower(str_replace(this->_actionSuffix, "", action)),
				routePrefix = this->_routePrefix;

			/**
			 * Check for existing paths in the annotation
			 */
			let paths = annotation->getNamedParameter("paths");
			if typeof paths != "array" {
				let paths = [];
			}

			/**
			 * Update the module if any
			 */
			if typeof module == "string" {
				let paths["module"] = module;
			}

			/**
			 * Update the namespace if any
			 */
			if typeof namespaceName == "string" {
				let paths["namespace"] = namespaceName;
			}

			let paths["controller"] = controller,
				paths["action"] = actionName;

			let value = annotation->getArgument(0);

			/**
			 * Create the route using the prefix
			 */
			if typeof value !== null {
				if value != "/" {
					let uri = routePrefix.value;
				} else {
					let uri = routePrefix;
				}
			} else {
				let uri = routePrefix.actionName;
			}

			/**
			 * Add the route to the router
			 */
			let route = this->add(uri, paths);

			/**
			 * Add HTTP constraint methods
			 */
			if methods !== null {
				let methods = annotation->getNamedParameter("methods");
				if typeof methods == "array" {
					route->via(methods);
				} else {
					if typeof methods == "string" {
						route->via(methods);
					}
				}
			} else {
				route->via(methods);
			}

			/**
			 * Add the converters
			 */
			let converts = annotation->getNamedParameter("converts");
			if typeof converts != "array" {
				for param, convert in converts {
					route->convert(param, convert);
				}
			}

			/**
			 * Add the conversors
			 */
			let converts = annotation->getNamedParameter("conversors");
			if typeof converts != "array" {
				for conversorParam, convert in converts {
					route->convert(conversorParam, convert);
				}
			}

			let routeName = annotation->getNamedParameter("name");
			if typeof routeName == "string" {
				route->setName(routeName);
			}

			return true;
		}

	}

	/**
	 * Changes the controller class suffix
	 *
	 * @param string controllerSuffix
	 */
	public function setControllerSuffix(string! controllerSuffix)
	{
		let this->_controllerSuffix = controllerSuffix;
	}

	/**
	 * Changes the action method suffix
	 *
	 * @param string actionSuffix
	 */
	public function setActionSuffix(string! actionSuffix)
	{
		let this->_actionSuffix = actionSuffix;
	}

	/**
	 * Return the registered resources
	 *
	 * @return array
	 */
	public function getResources()
	{
		return this->_handlers;
	}

}
